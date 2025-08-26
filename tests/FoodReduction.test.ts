
// import { describe, expect, it } from "vitest";

// const accounts = simnet.getAccounts();
// const address1 = accounts.get("wallet_1")!;

// /*
//   The test below is an example. To learn more, read the testing documentation here:
//   https://docs.hiro.so/stacks/clarinet-js-sdk
// */

// describe("example tests", () => {
//   it("ensures simnet is well initialised", () => {
//     expect(simnet.blockHeight).toBeDefined();
//   });

//   // it("shows an example", () => {
//   //   const { result } = simnet.callReadOnlyFn("counter", "get-counter", [], address1);
//   //   expect(result).toBeUint(0);
//   // });
// });

import { initSimnet } from "@hirosystems/clarinet-sdk";
import { Cl } from "@stacks/transactions";
import { describe, it, expect } from "vitest";

describe("Food waste reduction contract", () => {
  it("should list surplus food", async () => {
    const simnet = await initSimnet();
    const accounts = simnet.getAccounts();
    const user1 = accounts.get("wallet_1")!;

    const block = simnet.callPublicFn(
      "food-waste-reduction",
      "list-surplus-food",
      [
        Cl.stringAscii("Fresh Bread"),
        Cl.uint(20),
        Cl.uint(1000),
        Cl.stringAscii("Bakery Downtown"),
        Cl.uint(3),
      ],
      user1
    );

    expect(block.result.type).toBe("ok");
    expect(block.result).toStrictEqual(Cl.uint(1));
  });

  it("should allow claiming food", async () => {
    const simnet = await initSimnet();
    const accounts = simnet.getAccounts();
    const user1 = accounts.get("wallet_1")!;
    const user2 = accounts.get("wallet_2")!;

    // First list food
    simnet.callPublicFn(
      "food-waste-reduction",
      "list-surplus-food",
      [
        Cl.stringAscii("Fresh Vegetables"),
        Cl.uint(30),
        Cl.uint(1000),
        Cl.stringAscii("Farm Market"),
        Cl.uint(2),
      ],
      user1
    );

    // Then claim food
    const result = simnet.callPublicFn(
      "food-waste-reduction",
      "claim-food",
      [Cl.uint(1), Cl.uint(10)],
      user2
    );

    expect(result.result.type).toBe("ok");
  });
});

