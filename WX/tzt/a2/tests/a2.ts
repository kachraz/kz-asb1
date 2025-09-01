import * as anchor from "@coral-xyz/anchor";
import { Program } from "@coral-xyz/anchor";
import { A2 } from "../target/types/a2";

describe("a2", () => {
  // Configure the client to use the local cluster.
  anchor.setProvider(anchor.AnchorProvider.env());

  const program = anchor.workspace.a2 as Program<A2>;

  it("Is initialized!", async () => {
    // Add your test here.
    const tx = await program.methods.initialize().rpc();
    console.log("Your transaction signature", tx);
  });
});
