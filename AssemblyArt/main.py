from typing import Optional
from PIL import Image

NAME1 = "clearscreen"
FILENAME = NAME1 + ".png"
COMPRESSED_SIZE = (256, 256)
SCREEN_SIZE = (256, 256)

def RGB_to_HEX(rgb: tuple[int, ...]) -> str:
    return f"0x{''.join(f'{x:02x}' for x in rgb)}"

def xy_offset_to_hex(x: int, y: int) -> str:
    number = 4*((SCREEN_SIZE[1]*y) + x)
    return f"0x{number:08x}"

def int_to_hex(number: int) -> str:
    return f"0x{number:08x}"
def assemble_image(rgb_matrix: list[list[tuple[int, ...]]]) -> str:
    instructions = []
    counter = 0
    size = 0
    for y, row in enumerate(rgb_matrix):
        for x, rgb in enumerate(row):
            # if rgb == (0, 0, 0):
                # continue
            instructions.append(f"{xy_offset_to_hex(x, y)}, {RGB_to_HEX(rgb)}, ")
            counter += 1
            size += 1
            if counter == 12:
                instructions.append("\n")
                counter = 0
    instructions.insert(0, f"{int_to_hex(size)},\n")
    return "".join(instructions)


def draw_image(output_file: Optional[str] = None) -> None:
    with Image.open(FILENAME) as im:
        im = im.convert("RGB")
        im.thumbnail(COMPRESSED_SIZE, Image.Resampling.LANCZOS)
        im.save("compressed_image.png")

        width, height = im.size
        rgb_matrix = [
            [im.getpixel((x, y)) for x in range(width)]
            for y in range(height)
        ]
        output = assemble_image(rgb_matrix)
        if output_file:
            with open(output_file, "w") as file:
                file.write(output)
                print(f"Image assembled and saved to {output_file} with {width}x{height} resolution.")
        else:
            print(output)

if __name__ == "__main__":
    draw_image(NAME1)
