//! Token Monitor - Monitors AI token usage

use anyhow::Result;
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::path::PathBuf;
use std::sync::Arc;
use tokio::sync::{broadcast, RwLock};

/// Token usage information
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TokenUsage {
    pub ai_type: String,
    pub input_tokens: u64,
    pub output_tokens: u64,
    pub cache_tokens: Option<u64>,
    pub timestamp: String,
}

impl TokenUsage {
    pub fn total(&self) -> u64 {
        self.input_tokens + self.output_tokens
    }
}

/// Token Monitor - watches token log files
pub struct TokenMonitor {
    usage: Arc<RwLock<HashMap<String, TokenUsage>>>,
    event_sender: broadcast::Sender<TokenUsage>,
}

impl TokenMonitor {
    pub fn new() -> Self {
        let (event_sender, _) = broadcast::channel(100);
        Self {
            usage: Arc::new(RwLock::new(HashMap::new())),
            event_sender,
        }
    }

    /// Subscribe to token usage updates
    pub fn subscribe(&self) -> broadcast::Receiver<TokenUsage> {
        self.event_sender.subscribe()
    }

    /// Get token usage for an AI type
    pub async fn get_usage(&self, ai_type: &str) -> Option<TokenUsage> {
        let usage = self.usage.read().await;
        usage.get(ai_type).cloned()
    }

    /// Get all token usage
    pub async fn get_all_usage(&self) -> HashMap<String, TokenUsage> {
        let usage = self.usage.read().await;
        usage.clone()
    }

    /// Start monitoring token files
    pub async fn start_monitoring(&self, _data_dir: PathBuf) -> Result<()> {
        // In a full implementation, this would set up file watchers
        tracing::info!("Token monitoring started");
        Ok(())
    }

    /// Stop monitoring
    pub fn stop_monitoring(&self) {
        // Cleanup
    }

    /// Add token usage (for testing/API)
    pub async fn add_usage(&self, usage: TokenUsage) {
        {
            let mut usages = self.usage.write().await;
            usages.insert(usage.ai_type.clone(), usage.clone());
        }
        let _ = self.event_sender.send(usage);
    }
}

impl Default for TokenMonitor {
    fn default() -> Self {
        Self::new()
    }
}
