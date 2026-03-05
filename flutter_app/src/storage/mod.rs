//! Storage Module - Data persistence

use anyhow::Result;
use serde::{Deserialize, Serialize};
use std::path::PathBuf;
use tokio::fs;

/// Application configuration
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Config {
    pub appearance: String,
    pub font_size: f64,
    pub show_token_usage: bool,
    pub auto_connect: bool,
    pub server_port: u16,
    pub cloudflare_enabled: bool,
}

impl Default for Config {
    fn default() -> Self {
        Self {
            appearance: "system".to_string(),
            font_size: 14.0,
            show_token_usage: true,
            auto_connect: false,
            server_port: 8765,
            cloudflare_enabled: true,
        }
    }
}

/// Application storage
pub struct AppStorage {
    data_dir: PathBuf,
}

impl AppStorage {
    pub fn new() -> Result<Self> {
        let data_dir = dirs::data_local_dir()
            .unwrap_or_else(|| PathBuf::from("."))
            .join("BattleLM");

        // Create directory if not exists
        std::fs::create_dir_all(&data_dir)?;

        Ok(Self { data_dir })
    }

    /// Get config path
    fn config_path(&self) -> PathBuf {
        self.data_dir.join("config.json")
    }

    /// Get AI instances path
    fn ai_instances_path(&self) -> PathBuf {
        self.data_dir.join("ai_instances.json")
    }

    /// Get group chats path
    fn group_chats_path(&self) -> PathBuf {
        self.data_dir.join("group_chats.json")
    }

    /// Load configuration
    pub async fn load_config(&self) -> Result<Config> {
        let path = self.config_path();
        if !path.exists() {
            return Ok(Config::default());
        }

        let content = fs::read_to_string(&path).await?;
        let config: Config = serde_json::from_str(&content)?;
        Ok(config)
    }

    /// Save configuration
    pub async fn save_config(&self, config: &Config) -> Result<()> {
        let path = self.config_path();
        let content = serde_json::to_string_pretty(config)?;
        fs::write(&path, content).await?;
        Ok(())
    }

    /// Load AI instances
    pub async fn load_ai_instances<T: for<'de> Deserialize<'de>>(&self) -> Result<Vec<T>> {
        let path = self.ai_instances_path();
        if !path.exists() {
            return Ok(vec![]);
        }

        let content = fs::read_to_string(&path).await?;
        let instances: Vec<T> = serde_json::from_str(&content)?;
        Ok(instances)
    }

    /// Save AI instances
    pub async fn save_ai_instances<T: Serialize>(&self, instances: &[T]) -> Result<()> {
        let path = self.ai_instances_path();
        let content = serde_json::to_string_pretty(instances)?;
        fs::write(&path, content).await?;
        Ok(())
    }

    /// Load group chats
    pub async fn load_group_chats<T: for<'de> Deserialize<'de>>(&self) -> Result<Vec<T>> {
        let path = self.group_chats_path();
        if !path.exists() {
            return Ok(vec![]);
        }

        let content = fs::read_to_string(&path).await?;
        let chats: Vec<T> = serde_json::from_str(&content)?;
        Ok(chats)
    }

    /// Save group chats
    pub async fn save_group_chats<T: Serialize>(&self, chats: &[T]) -> Result<()> {
        let path = self.group_chats_path();
        let content = serde_json::to_string_pretty(chats)?;
        fs::write(&path, content).await?;
        Ok(())
    }

    /// Get data directory
    pub fn data_dir(&self) -> &PathBuf {
        &self.data_dir
    }

    /// Clear all data
    pub async fn clear_all(&self) -> Result<()> {
        fs::remove_file(self.config_path()).await.ok();
        fs::remove_file(self.ai_instances_path()).await.ok();
        fs::remove_file(self.group_chats_path()).await.ok();
        Ok(())
    }
}
