//! BattleLM Core - Cross-platform AI process management and WebSocket server

pub mod process_manager;
pub mod websocket;
pub mod token_monitor;
pub mod pty;
pub mod storage;

pub use process_manager::{AIInstance, AIType, ProcessManager, SessionHandle};
pub use websocket::{WSServer, WSConnection, WSMessageLocal, ServerMessage};
pub use token_monitor::{TokenUsage, TokenMonitor};
pub use storage::{AppStorage, Config};

use tracing_subscriber::{layer::SubscriberExt, util::SubscriberInitExt};

/// Initialize logging
pub fn init_logging() {
    tracing_subscriber::registry()
        .with(
            tracing_subscriber::EnvFilter::try_from_default_env()
                .unwrap_or_else(|_| "battle_lm_core=info,warn".into()),
        )
        .with(tracing_subscriber::fmt::layer())
        .init();
}
