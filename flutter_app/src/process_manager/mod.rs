//! Process Manager - AI process spawning and management

use anyhow::Result;
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::process::Stdio;
use std::sync::Arc;
use tokio::io::{AsyncBufReadExt, AsyncWriteExt, BufReader};
use tokio::process::{Child, Command};
use tokio::sync::{broadcast, mpsc, RwLock};
use uuid::Uuid;

/// AI type enumeration
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum AIType {
    Claude,
    Gemini,
    Codex,
    Qwen,
    Kimi,
}

impl AIType {
    pub fn cli_command(&self) -> &'static str {
        match self {
            AIType::Claude => "claude",
            AIType::Gemini => "gemini",
            AIType::Codex => "codex",
            AIType::Qwen => "qwen",
            AIType::Kimi => "kimi",
        }
    }
}

/// AI Instance
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AIInstance {
    pub id: String,
    pub name: String,
    pub ai_type: AIType,
    pub working_directory: String,
    pub tmux_session: String,
    pub is_active: bool,
    pub is_eliminated: bool,
    pub selected_model: Option<String>,
}

impl AIInstance {
    pub fn new(ai_type: AIType, name: Option<String>, working_directory: &str) -> Self {
        let id = Uuid::new_v4().to_string();
        Self {
            id: id.clone(),
            name: name.unwrap_or_else(|| format!("{:?}", ai_type)),
            ai_type,
            working_directory: working_directory.to_string(),
            tmux_session: format!("battlelm-{}", &id[..8]),
            is_active: false,
            is_eliminated: false,
            selected_model: None,
        }
    }
}

/// Session handle for active AI sessions
pub struct SessionHandle {
    pub ai_id: String,
    pub process: Option<Child>,
    pub input_tx: mpsc::Sender<String>,
    pub output_rx: mpsc::Receiver<String>,
}

/// Process Manager - manages AI process sessions
pub struct ProcessManager {
    sessions: Arc<RwLock<HashMap<String, SessionHandle>>>,
    event_sender: broadcast::Sender<ProcessEvent>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(tag = "type", content = "data")]
pub enum ProcessEvent {
    Started { ai_id: String },
    Stopped { ai_id: String },
    Output { ai_id: String, content: String },
    Error { ai_id: String, error: String },
}

impl ProcessManager {
    pub fn new() -> Self {
        let (event_sender, _) = broadcast::channel(100);
        Self {
            sessions: Arc::new(RwLock::new(HashMap::new())),
            event_sender,
        }
    }

    /// Subscribe to process events
    pub fn subscribe(&self) -> broadcast::Receiver<ProcessEvent> {
        self.event_sender.subscribe()
    }

    /// Start an AI session
    pub async fn start_session(&self, instance: &AIInstance) -> Result<()> {
        let ai_id = instance.id.clone();

        // Create channels for stdin/stdout
        let (input_tx, input_rx) = mpsc::channel::<String>(100);
        let (output_tx, output_rx) = mpsc::channel::<String>(100);

        // Spawn the AI process
        let mut child = Command::new("node")
            .arg(self.get_bridge_path(&instance.ai_type)?)
            .current_dir(&instance.working_directory)
            .stdin(Stdio::piped())
            .stdout(Stdio::piped())
            .stderr(Stdio::piped())
            .kill_on_drop(true)
            .spawn()?;

        // Take stdin
        if let Some(mut stdin) = child.stdin.take() {
            tokio::spawn(async move {
                let mut rx = input_rx;
                while let Some(msg) = rx.recv().await {
                    let _ = stdin.write_all(msg.as_bytes()).await;
                }
            });
        }

        // Handle stdout
        if let Some(stdout) = child.stdout.take() {
            let ai_id_clone = ai_id.clone();
            let tx = output_tx.clone();
            let event_sender = self.event_sender.clone();

            tokio::spawn(async move {
                let reader = BufReader::new(stdout);
                let mut lines = reader.lines();
                while let Ok(Some(line)) = lines.next_line().await {
                    let _ = tx.send(line.clone()).await;
                    let _ = event_sender.send(ProcessEvent::Output {
                        ai_id: ai_id_clone.clone(),
                        content: line,
                    });
                }
            });
        }

        // Store session
        let session = SessionHandle {
            ai_id: ai_id.clone(),
            process: Some(child),
            input_tx,
            output_rx,
        };

        self.sessions.write().await.insert(ai_id.clone(), session);

        // Send started event
        let _ = self.event_sender.send(ProcessEvent::Started { ai_id });

        Ok(())
    }

    /// Stop an AI session
    pub async fn stop_session(&self, ai_id: &str) -> Result<()> {
        let mut sessions = self.sessions.write().await;
        if let Some(mut session) = sessions.remove(ai_id) {
            if let Some(mut child) = session.process.take() {
                let _ = child.kill().await;
            }
            let _ = self.event_sender.send(ProcessEvent::Stopped {
                ai_id: ai_id.to_string(),
            });
        }
        Ok(())
    }

    /// Send message to AI
    pub async fn send_message(&self, ai_id: &str, message: &str) -> Result<()> {
        let sessions = self.sessions.read().await;
        if let Some(session) = sessions.get(ai_id) {
            session
                .input_tx
                .send(format!("{}\n", message))
                .await?;
        }
        Ok(())
    }

    /// Get bridge script path for AI type
    fn get_bridge_path(&self, ai_type: &AIType) -> Result<String> {
        // In a real implementation, this would find the bridge script
        // For now, return a placeholder
        let bridge_name = match ai_type {
            AIType::Claude => "claude-bridge.mjs",
            AIType::Gemini => "gemini-bridge.mjs",
            AIType::Codex => "codex-bridge.mjs",
            AIType::Qwen => "qwen-bridge.mjs",
            AIType::Kimi => "kimi-bridge.mjs",
        };

        // Try to find the bridge in common locations
        let possible_paths = vec![
            format!("./bridge/{}", bridge_name),
            format!("../bridge/{}", bridge_name),
            format!("/usr/local/bin/{}", bridge_name),
        ];

        for path in possible_paths {
            if std::path::Path::new(&path).exists() {
                return Ok(path);
            }
        }

        anyhow::bail!("Bridge script not found: {}", bridge_name)
    }

    /// Check if an AI is running
    pub async fn is_running(&self, ai_id: &str) -> bool {
        let sessions = self.sessions.read().await;
        sessions.contains_key(ai_id)
    }

    /// Get all active session IDs
    pub async fn active_sessions(&self) -> Vec<String> {
        let sessions = self.sessions.read().await;
        sessions.keys().cloned().collect()
    }
}

impl Default for ProcessManager {
    fn default() -> Self {
        Self::new()
    }
}
