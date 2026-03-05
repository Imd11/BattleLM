//! WebSocket Server - Handles remote connections

use anyhow::Result;
use futures_util::{SinkExt, StreamExt};
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::sync::Arc;
use tokio::net::{TcpListener, TcpStream};
use tokio::sync::{broadcast, RwLock};
use tokio_tungstenite::{accept_async, tungstenite::Message as WSMessage};

/// WebSocket message
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct WSMessageLocal {
    #[serde(rename = "type")]
    pub msg_type: String,
    pub payload: serde_json::Value,
}

impl WSMessageLocal {
    pub fn new(msg_type: &str, payload: impl Serialize) -> Result<Self> {
        Ok(Self {
            msg_type: msg_type.to_string(),
            payload: serde_json::to_value(payload)?,
        })
    }

    pub fn encode(&self) -> String {
        serde_json::to_string(self).unwrap_or_default()
    }

    pub fn decode(data: &str) -> Option<Self> {
        serde_json::from_str(data).ok()
    }
}

/// Connected WebSocket client
pub struct WSConnection {
    pub id: String,
    pub name: Option<String>,
    pub is_authenticated: bool,
    pub is_host: bool,
}

/// WebSocket Server
pub struct WSServer {
    connections: Arc<RwLock<HashMap<String, WSConnection>>>,
    broadcaster: broadcast::Sender<ServerMessage>,
    port: u16,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(tag = "type", content = "payload")]
pub enum ServerMessage {
    /// Broadcast to all clients
    Broadcast { target: String, message: WSMessageLocal },
    /// AI list update
    AIListUpdate { instances: Vec<serde_json::Value> },
    /// Group chat update
    GroupChatUpdate { chats: Vec<serde_json::Value> },
    /// Terminal prompt
    TerminalPrompt { ai_id: String, prompt: TerminalPrompt },
    /// Token usage update
    TokenUsage { usage: TokenUsageInfo },
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TerminalPrompt {
    pub ai_id: String,
    pub title: String,
    pub body: Option<String>,
    pub hint: Option<String>,
    pub options: Vec<PromptOption>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PromptOption {
    pub number: u32,
    pub label: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TokenUsageInfo {
    pub ai_type: String,
    pub input_tokens: u64,
    pub output_tokens: u64,
    pub timestamp: String,
}

impl WSServer {
    pub fn new(port: u16) -> Self {
        let (broadcaster, _) = broadcast::channel(1000);
        Self {
            connections: Arc::new(RwLock::new(HashMap::new())),
            broadcaster,
            port,
        }
    }

    /// Get broadcast receiver
    pub fn subscribe(&self) -> broadcast::Receiver<ServerMessage> {
        self.broadcaster.subscribe()
    }

    /// Start the WebSocket server
    pub async fn start(&self) -> Result<()> {
        let addr = format!("0.0.0.0:{}", self.port);
        let listener = TcpListener::bind(&addr).await?;

        tracing::info!("WebSocket server listening on {}", addr);

        loop {
            match listener.accept().await {
                Ok((stream, _)) => {
                    let connections = self.connections.clone();
                    let broadcaster = self.broadcaster.clone();

                    tokio::spawn(async move {
                        if let Err(e) = handle_connection(stream, connections, broadcaster).await {
                            tracing::error!("Connection error: {}", e);
                        }
                    });
                }
                Err(e) => {
                    tracing::error!("Accept error: {}", e);
                }
            }
        }
    }

    /// Broadcast message to all clients
    pub async fn broadcast(&self, msg: ServerMessage) {
        let _ = self.broadcaster.send(msg);
    }

    /// Get connected client count
    pub async fn client_count(&self) -> usize {
        self.connections.read().await.len()
    }

    /// Authenticate a connection
    pub async fn authenticate(&self, conn_id: &str, code: Option<&str>) -> bool {
        if code.is_some() {
            let mut connections = self.connections.write().await;
            if let Some(conn) = connections.get_mut(conn_id) {
                conn.is_authenticated = true;
                return true;
            }
        }
        false
    }
}

async fn handle_connection(
    stream: TcpStream,
    connections: Arc<RwLock<HashMap<String, WSConnection>>>,
    broadcaster: broadcast::Sender<ServerMessage>,
) -> Result<()> {
    let ws_stream = accept_async(stream).await?;
    let (mut write, mut read) = ws_stream.split();

    let conn_id = uuid::Uuid::new_v4().to_string();

    // Register connection
    {
        let mut conns = connections.write().await;
        conns.insert(
            conn_id.clone(),
            WSConnection {
                id: conn_id.clone(),
                name: None,
                is_authenticated: false,
                is_host: false,
            },
        );
    }

    // Handle incoming messages
    while let Some(msg) = read.next().await {
        match msg {
            Ok(WSMessage::Text(text)) => {
                if let Some(ws_msg) = WSMessageLocal::decode(&text) {
                    let _ = handle_message(&conn_id, ws_msg, &connections).await;
                    // Send response
                    let response = WSMessageLocal::new("ack", serde_json::json!({}))?;
                    let _ = write.send(WSMessage::Text(response.encode())).await;
                }
            }
            Ok(WSMessage::Close(_)) => break,
            Err(e) => {
                tracing::error!("WebSocket error: {}", e);
                break;
            }
            _ => {}
        }
    }

    // Cleanup
    {
        let mut conns = connections.write().await;
        conns.remove(&conn_id);
    }

    tracing::info!("Connection {} disconnected", conn_id);
    Ok(())
}

async fn handle_message(
    conn_id: &str,
    msg: WSMessageLocal,
    connections: &Arc<RwLock<HashMap<String, WSConnection>>>,
) -> Result<()> {
    match msg.msg_type.as_str() {
        "pairing" => {
            let code = msg.payload.get("code").and_then(|v| v.as_str());
            let server = WSServer::new(8765);
            let _ = server.authenticate(conn_id, code).await;
        }
        "getCapabilities" => {
            tracing::debug!("Capabilities requested");
        }
        "getAIList" => {
            tracing::debug!("AI list requested");
        }
        "chatMessage" => {
            tracing::debug!("Chat message: {:?}", msg.payload);
        }
        _ => {
            tracing::warn!("Unknown message type: {}", msg.msg_type);
        }
    }

    Ok(())
}
