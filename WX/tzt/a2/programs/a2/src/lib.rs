use anchor_lang::prelude::*;

declare_id!("BqZyBSFqYrqh5c3XefEdNYM5zTEq5Nudg3t9kLHmwYbB");

#[program]
pub mod a2 {
    use super::*;

    pub fn initialize(ctx: Context<Initialize>) -> Result<()> {
        msg!("Greetings from: {:?}", ctx.program_id);
        Ok(())
    }
}

#[derive(Accounts)]
pub struct Initialize {}
