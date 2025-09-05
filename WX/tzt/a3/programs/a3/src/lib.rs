use anchor_lang::prelude::*;

declare_id!("H8tcHEeEPueCctQgsXGJ3CVuWppquHySRWUTou1xi7G");

#[program]
pub mod a3 {
    use super::*;

    pub fn initialize(ctx: Context<Initialize>) -> Result<()> {
        msg!("Smell Panty: {:?}", ctx.program_id);
        Ok(())
    }

    pub fn update(ctx: Context<Update>) -> Result<()> {
        msg!("LickPussy: {:?}", ctx.program_id);
        Ok(())
    }
}

#[derive(Accounts)]
pub struct Initialize {}

#[derive(Accounts)]
pub struct Update {}
