use anchor_lang::prelude::*;

declare_id!("5X7JTazhRzHfBi9ucRLnsRJSPb2CwxCmYq6qbzZeAzx");

#[program]
pub mod a3 {
    use super::*;

    pub fn initialize(ctx: Context<Initialize>) -> Result<()> {
        msg!("Smell Panty: {:?}", ctx.program_id);
        Ok(())
    }
}

#[derive(Accounts)]
pub struct Initialize {}
