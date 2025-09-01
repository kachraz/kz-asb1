use anchor_lang::prelude::*;

declare_id!("3s8r3yo4zxrPDG88E1TurPC5EiPzphnbF9Dvv6kBRhAL");

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
