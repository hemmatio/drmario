.data
ADDR_DSPL:
    .word 0x10008000       # Base address for the bitmap display

image_width:
    .word 256              # Width of the image
image_height:
    .word 256              # Height of the image

# Include the image data
background:
  .include "background"  # Include the raw pixel data

.text
    .globl main

main:
    # Load base address of the display
    lw $t0, ADDR_DSPL      # $t0 = base address for display

    # Load image dimensions
    lw $t1, image_width    # $t1 = image width (256)
    lw $t2, image_height   # $t2 = image height (256)

    # Load address of image data
    la $t3, background     # $t3 = address of image data

    # Initialize counters
    li $t4, 0              # $t4 = row counter (y)
    li $t5, 0              # $t5 = column counter (x)

render_loop:
    # Calculate the offset for the current pixel in the image data
    mult $t6, $t4, $t1      # $t6 = y * width
    add $t6, $t6, $t5      # $t6 = y * width + x
    sll $t6, $t6, 2        # $t6 = (y * width + x) * 4 (each pixel is 4 bytes)

    # framebuffer location = display address + pixel location
    add $t8, $t0, $t6      # $t8 = address of current pixel in framebuffer

    # image pixel offset = image data location + pixel location
    add $t6, $t3, $t6      # $t6 = address of current pixel in image data

    # Load the pixel value from image data
    lw $t7, 0($t6)         # $t7 = pixel value (0x00000000 format)

    # Write the pixel value to the framebuffer
    sw $t7, 0($t8)         # Draw pixel

    # Increment column counter (x)
    addi $t5, $t5, 1       # x = x + 1
    blt $t5, $t1, render_loop  # If x < width, continue to next column

    # Reset column counter (x) and increment row counter (y)
    li $t5, 0              # Reset x to 0
    addi $t4, $t4, 1       # y = y + 1
    blt $t4, $t2, render_loop  # If y < height, continue to next row

exit:
    li $v0, 10             # Terminate the program gracefully
    syscall