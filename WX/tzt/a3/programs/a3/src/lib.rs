use anchor_lang::prelude::*;

declare_id!("AW5Swy7B8vcL9HSNb3HcErMoKPgthb41FhLEWCZB4wqA");

#[program]
pub mod a3 {
    use super::*;

    pub fn initialize(ctx: Context<Initialize>) -> Result<()> {
        msg!("Greetings from: {:?}", ctx.program_id);
        Ok(())
    }
}

#[derive(Accounts)]
pub struct Initialize {}
