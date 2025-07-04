# Dr. Mario (MIPS)

A MIPS assembly remake of Nintendo’s classic **Dr. Mario** puzzle game. Pills fall from the top of the screen and the player must align colors to clear out viruses.

---

This game **must be run using the [Saturn MIPS emulator](https://github.com/1whatleytay/saturn)**.

---

## How to View the Game

To run and view the game correctly in **Saturn**, make sure the following settings are configured:

1. **Set the bitmap display size** to **256px by 256px** (width and height), with **units set to 1**.
2. **Set the bitmap display address** to: 0x10008000
3. Ensure **no asset files are missing** from the `assets/` directory. These include bitmap data used to render pills, viruses, and other sprites.
