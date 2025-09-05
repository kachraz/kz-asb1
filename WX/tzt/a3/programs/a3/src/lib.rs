use anchor_lang::prelude::*;

declare_id!("8ywxnddq1a4n5mCeHYgvNV3fW8hVK66QJjri1vCZeUMY");

#[program]
pub mod a3 {
    use super::*;

    pub fn initialize(ctx: Context<Initialize>) -> Result<()> {
        msg!("Smell Panty: {:?}", ctx.program_id);
        Ok(())
    }

    pub fn update(ctx: Context<update>) -> Result<()> {
        msg!("LickPussy: {:?}", ctx.program_id);
        Ok(())
    }
}

#[derive(Accounts)]
pub struct Initialize {}

#[derive(Accounts)]
pub struct Update {}
