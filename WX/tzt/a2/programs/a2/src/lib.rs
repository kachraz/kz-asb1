use anchor_lang::prelude::*;

declare_id!("HSxcvT5hb4gYYGQsg7KkcX5eSgspPwHSBnwhWqwWC7x5");

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
