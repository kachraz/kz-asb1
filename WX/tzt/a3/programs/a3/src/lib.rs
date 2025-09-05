use anchor_lang::prelude::*;

declare_id!("4MsifEas8pV11UMnYSabKkkkbqDrFnjUkwqR2mdhd2aK");

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
