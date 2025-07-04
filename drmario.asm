# 2. How to view the game:
# (a) Set the bitmap to be 256px by 256px, the units are 1
# (b) The bitmap display address should be 0x10008000
# (c) Make sure no asset files are missing from the assests folder

.data
buffer: .space 1000000
  
ADDR_DSPL:
    .word 0x10008000
ADDR_KBRD:
    .word 0xffff0000
asset_background:
    .include "assets/asset_background"  # PLAYABLE AREA: 63 x 126
# asset_daddy:
    # .include "assets/ricardo"
asset_red_virus:
    .include "assets/redvirus"
asset_red_pill:
    .include "assets/redpill"
asset_yellow_virus:
    .include "assets/yellowvirus"
asset_yellow_pill:
    .include "assets/yellowpill"
asset_blue_virus:
    .include "assets/bluevirus"
asset_blue_pill:
    .include "assets/bluepill"
asset_brack:
    .include "assets/brack"
asset_white_pill:
    .include "assets/whitepill"
asset_red_virus_1:
    .include "assets/redvirus_1"
asset_red_virus_2:
    .include "assets/redvirus_2"
asset_red_virus_3:
    .include "assets/redvirus_3"
asset_red_virus_4:
    .include "assets/redvirus_4"
asset_red_virus_5:
    .include "assets/redvirus_5"
asset_red_virus_6:
    .include "assets/redvirus_6"
asset_yellow_virus_1:
    .include "assets/yellowvirus_1"
asset_yellow_virus_2:
    .include "assets/yellowvirus_2"
asset_yellow_virus_3:
    .include "assets/yellowvirus_3"
asset_yellow_virus_4:
    .include "assets/yellowvirus_4"
asset_yellow_virus_5:
    .include "assets/yellowvirus_5"
asset_yellow_virus_6:
    .include "assets/yellowvirus_6"
asset_blue_virus_1:
    .include "assets/bluevirus_1"
asset_blue_virus_2:
    .include "assets/bluevirus_2"
asset_blue_virus_3:
    .include "assets/bluevirus_3"
asset_blue_virus_4:
    .include "assets/bluevirus_4"
asset_blue_virus_5:
    .include "assets/bluevirus_5"
asset_blue_virus_6:
    .include "assets/bluevirus_6"
asset_magnifying_glass:
    .include "assets/magnifying_glass"
asset_ricardo_1:
    .include "assets/ricardo_1"
asset_ricardo_2:
    .include "assets/ricardo_2"
asset_clear_ricardo:
    .include "assets/clear_ricardo"
asset_youlose:
    .include "assets/youlose"
asset_pauseclear:
    .include "assets/pauseclear"
asset_gamepause:
    .include "assets/gamepaused"
asset_clearscreen:
    .include "assets/clearscreen"

buffer2: .space 1000000  # ∑ ∑ boy ∑ boy ∑ boy


# s0, s1, and s2 are pill positions
# s7 is a time register
# s6 is a frame register
# s5: interrupt animation. s5 = 0 <=> interrupt animation, s5 = 1 <=> continue animations
# s4: speed factor
    
.text
.globl main

.macro push(%reg)
	sub $sp, $sp, 4
	sw  %reg, 0($sp)	# push %reg
.end_macro

.macro pop(%reg)
	lw  %reg, 0($sp)	# pop %reg
	add $sp, $sp, 4
.end_macro

# This macro will swap the values in %a and %b
# Precondition: %a and %b cannot be stored in $t0
.macro swap(%a %b)
   push($t0)
   add $t0 $zero %a
   add %a $zero %b
   add %b $zero $t0
   pop($t0)
.end_macro

# Quit the game gracefully
.macro quit()
    li $v0 10
    syscall
.end_macro

# Given a register, set the kth bit to 1, leaving all other bits the same.
.macro setbit(%reg %k)
    push($t0)
    push($t1)
    add $t0 $zero %k
    addi $t1 $zero 1
    sllv $t0 $t1 $t0 # shift 1 by k bits
    or %reg %reg $t0
    pop($t1)
    pop($t0)
.end_macro

# Get the value of the kth bit of a register and store it in a destination register.
# Usage: getbit($reg, k) => $v0 = ($reg >> k) & 1
.macro getbit(%reg, %k)
    push($t9)
    addi $t9, $zero, 1         # $t0 = 1
    sllv  $t9, $t9, %k          # $t0 = 1 << k
    and  $v0, %reg, $t9      # %dest = %reg & (1 << k)
    srlv  $v0, $v0, %k      # Shift result down to bit 0
    pop($t9)
.end_macro

# The system sleeps for %time milliseconds
.macro sleep(%time)
    push($v0)
    push($a0)
    li $v0 , 32
    li $a0 , %time
    syscall
    pop($a0)
    pop($v0)
.end_macro

  # Macro to draw the %data asset, offsetted by a value of %offset
.macro load_asset(%data, %offset)
	push($t0)
    push($t1)
    push($a0)
    push($a1)
    la $t0 %data
    lw $t1 0($t0) #Read the size of the file
    addi $t0 $t0 4 #Skip to the first offset colour pair
    
    draw_asset_loop:
        lw $a0 0($t0) #Offset
        add $a0 $a0 %offset
        lw $a1 4($t0) #Colour
        
        draw($a0, $a1)
        addi $t0 $t0 8 #Go to the next offset colour pair
        subi $t1 $t1 1
        bgtz $t1, draw_asset_loop

    pop($a1)
    pop($a0)
    pop($t1)
    pop($t0)
.end_macro

.macro draw(%offset, %colour)
	push($t2)
    lw $t2, ADDR_DSPL
    add $t2 $t2 %offset
    sw %colour 0( $t2 )
    pop($t2)
.end_macro

# Stores the offset value in $v0
# i is an input containing an integer between 0 and 161 stored in a register
# Then, our offset is $t0 + 82304 + (x * 28) + (y * 7168)
.macro grid_to_offset(%i)
    # save previous values of $t0-$t2
    push($t0)
    push($t1)
    push($t2)
    push($t3)
    add $t0 $zero %i  # store value of %i in $t0
    addi $t3 $zero 9
    div $t0 $t3  # lo = $t0 / 9, hi = $t0 % 9
    mfhi $t1  # x = $t1
    mflo $t2  # y = $t2
    addi $t3 $zero 28
    mult $t1 $t3
    mflo $t1 # x = $t1 * 28
    addi $t3 $zero 7168
    mult $t2 $t3
    mflo $t2 # y = $t1 * 7168
    addi $t0 $zero 82304  # set $t0 to be the top left corner of the playable area
    add $t0 $t0 $t1  # add x offset to curr pixel
    add $t0 $t0 $t2  # add y offset to curr pixel
    move $v0 $t0  # move $t0 to return value
    # set $t0-$t2 to whatever they were before
    pop($t3)
    pop($t2)
    pop($t1)
    pop($t0)
.end_macro

# Stores the offset value in $v0
# i is an input containing an integer between 0 and 161 stored in a register.
# Used for colour dectection. The pixel selected is (0,3) relative to the top-left of any 7x7 pixel grid index.
.macro grid_middle_offset(%grid)
    grid_to_offset(%grid)
    addi $v0 $v0 3072
.end_macro

# Returns:
#   Random number in the range [0, max - 1], store is $v0
.macro rand_between(%max)
    # Get a random number using syscall
    push($a0)
    push($a1)
    li $v0 42
    li $a0 0
    li $a1 %max
    syscall
    move $v0 $a0
    pop($a1)
    pop($a0)
.end_macro

.macro draw_starter_virus()
    push($t0)
    push($t1)
    push($t2)
    push($t3)
    push($t5)
    push($a0)
    push($a3)
    push($v0)
    add $t0 $zero $s4  # This is the number of viruses to spawn.
    li $t1 0
    li $t2 1
    li $t3 2

    # Note: $a0 and $a1 are used a lot so their values are unstable
    draw_virus_loop:
        rand_between(3)
        move $t5 $v0
        
        
        rand_between(99) # get the random grid of where to spawn, but only ~60% of total height
        addi $a0 $v0 63  # add to ~40% of height
        reset_grid($a0)
        grid_to_offset($a0)
        add $a3 $zero $v0

        #TODO: make sure 2 viruses dont spawn in the same section
        beq $t5 $t1 if_virus_rand_is_0
        beq $t5 $t2 if_virus_rand_is_1
        beq $t5 $t3 if_virus_rand_is_2
        
        # If statment based on the return value of rand_between
        if_virus_rand_is_0: # Colour Red
          load_asset(asset_red_virus, $a3)
          j end_virus_colour_rand
        if_virus_rand_is_1: # Colour Blue
          load_asset(asset_blue_virus, $a3)
          j end_virus_colour_rand
        if_virus_rand_is_2: # Colour Yellow
          load_asset(asset_yellow_virus, $a3)
          j end_virus_colour_rand
        end_virus_colour_rand:
        subi $t0 $t0 1
        bgtz $t0 draw_virus_loop
    pop($v0)
    pop($a3)
    pop($a0)
    pop($t5)
    pop($t3)
    pop($t2)
    pop($t1)
    pop($t0)
.end_macro


.macro pill_creation()
    push($t0)
    push($t1)
    push($t2)
    push($a2)
    push($a3)
    push($v0)
    addi $t0 $zero 4
    collide_bottom($t0)
    bne $v0 4 lose_setup # if theres a pill at the offset, stop the game
    rand_between(3)
    move $t0 $v0  # store the random value in $t0, this is top pill segment
    rand_between(3)
    move $t1 $v0  # store the random vlaue in $t1, this is the bottom pill segment
    addi $a2 $zero 4  # index of top half of pill 
    addi $a3 $zero 13  # index of bottom half of pill
    grid_to_offset($a2)
    move $a2 $v0  # store pixel location of index 4
    grid_to_offset($a3)
    move $a3 $v0  # store pixel location of index 13

    addi $t2 $zero 0  # set $t2 to be zero
    beq $t0 $t2 if_pill_rand_is_0_top
    addi $t2 $t2 1
    beq $t0 $t2 if_pill_rand_is_1_top
    addi $t2 $t2 1
    beq $t0 $t2 if_pill_rand_is_2_top

    if_pill_rand_is_0_top: # Colour Red
      load_asset(asset_red_pill, $a2)
      j end_pill_colour_rand_top
    if_pill_rand_is_1_top: # Colour Blue
      load_asset(asset_blue_pill, $a2)
      j end_pill_colour_rand_top
    if_pill_rand_is_2_top: # Colour Yellow
      load_asset(asset_yellow_pill, $a2)
      j end_pill_colour_rand_top
    end_pill_colour_rand_top:

    addi $t2 $zero 0  # set $t2 to be zero
    beq $t1 $t2 if_pill_rand_is_0_bottom
    addi $t2 $t2 1
    beq $t1 $t2 if_pill_rand_is_1_bottom
    addi $t2 $t2 1
    beq $t1 $t2 if_pill_rand_is_2_bottom
    
    if_pill_rand_is_0_bottom: # Colour Red
      load_asset(asset_red_pill, $a3)
      j end_pill_colour_rand_bottom
    if_pill_rand_is_1_bottom: # Colour Blue
      load_asset(asset_blue_pill, $a3)
      j end_pill_colour_rand_bottom
    if_pill_rand_is_2_bottom: # Colour Yellow
      load_asset(asset_yellow_pill, $a3)
      j end_pill_colour_rand_bottom
    end_pill_colour_rand_bottom: 
    addi $s0 $zero 4 # Stores the starting positon of the pill
    addi $s1 $zero 13 # Stores the starting positon of the pill
    addi $s2 $zero 0 # Vertical orientation stored
    push($v0)
    pop($a3)
    pop($a2)
    pop($t2)
    pop($t1)
    pop($t0)
.end_macro


# Draws a pill segment at the grid index %grid, with colour %colour
# Does not update $v0
# Param %colour:
  # 0 : red 
  # 1 : blue 
  # 2 : yellow 
# Param %grid:
  # %grid \in (0, 161)
.macro draw_pill_segment(%grid, %colour)
    push($t0)
    push($t1)
    push($v0)
    push($a2)
    add $t0 $zero %grid  # store the grid in $t0
    add $t1 $zero %colour  # store the colour in $t1
    grid_to_offset($t0)  # get the pixel address of the selected grid
    move $a2 $v0  # store the pixel address in $t0

    addi $t0 $zero 0
    beq $t0 $t1 if_draw_segment_is_red
    addi $t0 $zero 1
    beq $t0 $t1 if_draw_segment_is_blue
    addi $t0 $zero 2
    beq $t0 $t1 if_draw_segment_is_yellow
    if_draw_segment_is_red:
        load_asset(asset_red_pill, $a2)
        j end_pill_segment_draw
    if_draw_segment_is_yellow:
        load_asset(asset_yellow_pill, $a2)
        j end_pill_segment_draw
    if_draw_segment_is_blue:
        load_asset(asset_blue_pill, $a2)
        j end_pill_segment_draw
    end_pill_segment_draw:
    pop($a2)
    pop($v0)
    pop($t1)
    pop($t0)
.end_macro


# Sets the return value to register $v0
# ra = 0 : collide with red
# ra = 1 : collide with blue
# ra = 2 : collide with yellow
# ra = 3 : collide with bottle
# ra = 4 : no collision occurs
.macro collide_left(%grid)
    push($t0)
    push($t1)
    grid_middle_offset(%grid) #Get the middle offset, which displays constant colour
    subi $t0 $v0 28 # move offset over by 7 values
    lw $t1 ADDR_DSPL
    add $t0 $t1 $t0 # Stores the top left of the entire screen, plus the offset
    lw $t1 0( $t0 ) # Gets the value stored in memory, at that box

    addi $t0 $zero 0xD84060 #Colour code for red
    beq $t0 $t1 if_grid_collision_left_is_red
    addi $t0 $zero 0x60A0FF #Colour code for blue
    beq $t0 $t1 if_grid_collision_left_is_blue
    addi $t0 $zero 0xE8D020 #Colour code for yellow
    beq $t0 $t1 if_grid_collision_left_is_yellow
    addi $t0 $zero 0x4ACEDE #Colour code for bottle
    beq $t0 $t1 if_grid_collision_left_is_bottle
    j else_if_no_collision_left # else jump to no condition

    if_grid_collision_left_is_red:
        addi $v0 $zero 0
        j end_if_grid_collision_left
    if_grid_collision_left_is_blue:
        addi $v0 $zero 1
        j end_if_grid_collision_left
    if_grid_collision_left_is_yellow:
        addi $v0 $zero 2
        j end_if_grid_collision_left
    if_grid_collision_left_is_bottle:
        addi $v0 $zero 3
        j end_if_grid_collision_left
    else_if_no_collision_left:
        addi $v0 $zero 4
        j end_if_grid_collision_left
    end_if_grid_collision_left:
    
    pop($t1)
    pop($t0)
.end_macro

# Sets the return value to register $v0
# ra = 0 : collide with red
# ra = 1 : collide with blue
# ra = 2 : collide with yellow
# ra = 3 : collide with bottle
# ra = 4 : no collision occurs
.macro collide_right(%grid)
    push($t0)
    push($t1)
    grid_middle_offset(%grid) #Get the middle offset, which displays constant colour
    addi $t0 $v0 28  #Add 7 to go to the next box over
    addi $t0 $t0 0x10008000 # Stores the top left corner of the entire screen, plus the offset
    lw $t1 0( $t0 ) # Gets the value stored in memory, at that box

    addi $t0 $zero 0xD84060 #Colour code for red
    beq $t0 $t1 if_grid_collision_right_is_red
    addi $t0 $zero 0x60A0FF #Colour code for blue
    beq $t0 $t1 if_grid_collision_right_is_blue
    addi $t0 $zero 0xE8D020 #Colour code for yellow
    beq $t0 $t1 if_grid_collision_right_is_yellow
    addi $t0 $zero 0x4ACEDE #Colour code for bottle
    beq $t0 $t1 if_grid_collision_right_is_bottle
    j else_if_no_collision_right
  
    if_grid_collision_right_is_red:
        addi $v0 $zero 0
        j end_if_grid_collision_right
    if_grid_collision_right_is_blue:
        addi $v0 $zero 1
        j end_if_grid_collision_right
    if_grid_collision_right_is_yellow:
        addi $v0 $zero 2
        j end_if_grid_collision_right
    if_grid_collision_right_is_bottle:
        addi $v0 $zero 3
        j end_if_grid_collision_right
    else_if_no_collision_right:
        addi $v0 $zero 4
        j end_if_grid_collision_right
    end_if_grid_collision_right:
    pop($t1)
    pop($t0)
.end_macro



# Sets the return value to register $v0
# ra = 0 : collide with red
# ra = 1 : collide with blue
# ra = 2 : collide with yellow
# ra = 3 : collide with bottle
# ra = 4 : no collision occurs
.macro collide_bottom(%grid)
    push($t0)
    push($t1)
    grid_middle_offset(%grid) #Get the middle offset, which displays constant colour
    addi $t0 $v0 7168  #Increases the y value by 7
    addi $t0 $t0 0x10008000 # Stores the top left corner of the entire screen, plus the offset
    lw $t1 0( $t0 ) # Gets the value stored in memory, at that box

    addi $t0 $zero 0xD84060 #Colour code for red
    beq $t0 $t1 if_grid_collision_bottom_is_red
    addi $t0 $zero 0x60A0FF #Colour code for blue
    beq $t0 $t1 if_grid_collision_bottom_is_blue
    addi $t0 $zero 0xE8D020 #Colour code for yellow
    beq $t0 $t1 if_grid_collision_bottom_is_yellow
    addi $t0 $zero 0x4ACEDE #Colour code for bottle
    beq $t0 $t1 if_grid_collision_bottom_is_bottle
    addi $t0 $zero 0x3900a5
    beq $t0 $t1 if_grid_collision_bottom_is_bottle
    j else_if_no_collision_bottom
  
    if_grid_collision_bottom_is_red:
        addi $v0 $zero 0
        j end_if_grid_collision_bottom
    if_grid_collision_bottom_is_blue:
        addi $v0 $zero 1
        j end_if_grid_collision_bottom
    if_grid_collision_bottom_is_yellow:
        addi $v0 $zero 2
        j end_if_grid_collision_bottom
    if_grid_collision_bottom_is_bottle:
        addi $v0 $zero 3
        j end_if_grid_collision_bottom
    else_if_no_collision_bottom:
        addi $v0 $zero 4
        j end_if_grid_collision_bottom
    end_if_grid_collision_bottom:
    pop($t1)
    pop($t0)
.end_macro

.macro collide_top(%grid)
    push($t0)
    push($t1)
    grid_middle_offset(%grid)
    subi $t0 $v0 7168  # Decrease the y value by 7 pixels
    addi $t0 $t0 0x10008000 # Stores the top left corner of the entire screen, plus the offset
    lw $t1 0( $t0 ) # Gets the value stored in memory, at that box

    addi $t0 $zero 0xD84060 #Colour code for red
    beq $t0 $t1 if_grid_collision_top_is_red
    addi $t0 $zero 0x60A0FF #Colour code for blue
    beq $t0 $t1 if_grid_collision_top_is_blue
    addi $t0 $zero 0xE8D020 #Colour code for yellow
    beq $t0 $t1 if_grid_collision_top_is_yellow
    addi $t0 $zero 0x4ACEDE #Colour code for bottle
    beq $t0 $t1 if_grid_collision_top_is_bottle
    addi $t0 $zero 0x3900a5
    beq $t0 $t1 if_grid_collision_top_is_bottle
    j else_if_no_collision_top
  
    if_grid_collision_top_is_red:
        addi $v0 $zero 0
        j end_if_grid_collision_top
    if_grid_collision_top_is_blue:
        addi $v0 $zero 1
        j end_if_grid_collision_top
    if_grid_collision_top_is_yellow:
        addi $v0 $zero 2
        j end_if_grid_collision_top
    if_grid_collision_top_is_bottle:
        addi $v0 $zero 3
        j end_if_grid_collision_top
    else_if_no_collision_top:
        addi $v0 $zero 4
        j end_if_grid_collision_top
    end_if_grid_collision_top:
    pop($t1)
    pop($t0)
.end_macro

.macro collide_vert_rotate()
    push($t0)
    push($t1)
    grid_middle_offset($s0)  # get the middle-left pixel offset of the moving pill segment 
    addi $t0 $v0 7196  # shift pixel one to the right, one down
    addi $t0 $t0 0x10008000 # Stores the top left corner of the entire screen, plus the offset
    lw $t1 0( $t0 )
    bgtz $t1 if_grid_collision_vert_rotate
    j if_no_collide_vert_rotate

    if_grid_collision_vert_rotate:
        addi $v0 $zero 3
        j end_if_collide_vert_rotate

    if_no_collide_vert_rotate:
        add $v0 $zero $zero
    end_if_collide_vert_rotate:
    pop($t1)
    pop($t0)
.end_macro


.macro collide_horz_rotate()
    push($t0)
    push($t1)
    grid_middle_offset($s1)  # get the middle-left pixel offset of the moving pill segment 
    subi $t0 $v0 7196  # shift pixel one to the right, one down
    addi $t0 $t0 0x10008000 # Stores the top left corner of the entire screen, plus the offset
    lw $t1 0( $t0 )
    bgtz $t1 if_grid_collision_horz_rotate
    j if_no_collide_horz_rotate

    if_grid_collision_horz_rotate:
        addi $v0 $zero 3
        j end_if_collide_horz_rotate

    if_no_collide_horz_rotate:
        add $v0 $zero $zero
    end_if_collide_horz_rotate:
    pop($t1)
    pop($t0)
.end_macro

# This function will check if a key has been pressed. 
# Will store result in $v0, where $v0 is false on 0, and true ow
.macro key_pressed()
    push($t0)
    addi $t0 $zero 0xffff0000
    lw $v0 0($t0)
    pop($t0)
.end_macro

# This function will set the value of $v0, to specify which key has been pressed.
# Params:
#   %pressed will be either a 0 or 1, if a key has been pressed
# Returns:
#   0: No key has been pressed
#   1: W has been pressed
#   2: A has been pressed
#   3: S has been pressed
#   4: D has been pressed
#   5: R has been pressed
#   5: P has been pressed
#   Qiut: q is pressed
.macro which_key(%pressed)
    push($t0)
    push($t1)
    move $t0 %pressed # Store value of pressed
    is_next_frame()
    beq $t0 $zero if_key_pressed_none # if no key has been pressed
    
    add $t0 $zero 0xffff0000  # store address of ADDR_KBRDaa
    lw $t0 4($t0)
    addi $t1 $zero 0x61
    beq $t1 $t0 if_key_pressed_a
    addi $t1 $zero 0x73
    beq $t1 $t0 if_key_pressed_s
    addi $t1 $zero 0x64
    beq $t1 $t0 if_key_pressed_d
    addi $t1 $zero 0x77
    beq $t1 $t0 if_key_pressed_w
    addi $t1 $zero 0x72
    beq $t1 $t0 if_key_pressed_r
    addi $t1 $zero 0x70
    beq $t1 $t0 if_key_pressed_p
    addi $t1 $zero 0x71
    beq $t1 $t0 if_key_pressed_q
    j if_key_pressed_none
    # If statement on which key is pressed
    if_key_pressed_a:
      addi $v0 $zero 2
      j end_of_which_key
    if_key_pressed_s:
      addi $v0 $zero 3
      j end_of_which_key
    if_key_pressed_d:
      addi $v0 $zero 4
      j end_of_which_key
    if_key_pressed_w:
      addi $v0 $zero 1
      j end_of_which_key
    if_key_pressed_r:
      addi $v0 $zero 5
      j end_of_which_key
    if_key_pressed_p:
      addi $v0 $zero 6
      j end_of_which_key
    if_key_pressed_none:
      add $v0 $zero $zero
      j end_of_which_key
    if_key_pressed_q:
      quit()
    end_of_which_key:
    pop($t1)
    pop($t0)
.end_macro

# down two pixels then right two pixels from grid_middle_offset for a total of (5,2)
# returns 1 if the given grid is a pill, 0 otherwise.
.macro is_pill(%grid)
    push($t0)
    push($t1)
    grid_to_offset(%grid)
    addi $t0 $v0 5128 # add five right and two down
    lw $t1 ADDR_DSPL
    add $t0 $t1 $t0 # Stores the top left of the entire screen, plus the offset
    lw $t1 0( $t0 ) # Gets the value stored in memory, at that box

    addi $t0 $zero 0xD84060 #Colour code for red
    beq $t0 $t1 grid_is_pill
    addi $t0 $zero 0x60A0FF #Colour code for blue
    beq $t0 $t1 grid_is_pill
    addi $t0 $zero 0xE8D020 #Colour code for yellow
    beq $t0 $t1 grid_is_pill
    j grid_is_not_pill

    grid_is_pill:
        addi $v0 $zero 1
        j is_pill_end
    grid_is_not_pill:
        add $v0 $zero $zero
        j is_pill_end

    is_pill_end:
        pop($t1)
        pop($t0)
.end_macro


# returns 1 if the given grid is a virus, 0 otherwise.
.macro is_virus(%grid)
    push($t1)
    get_grid_colour(%grid) # gets the grids colour
    addi $t1 $zero 5
    beq $v0 $t1 if_not_grid_primary_colour # if the colour is not red, blue or yellow
    j if_grid_primary_colour
    if_not_grid_primary_colour:
        add $v0 $zero 0 # trivally cannot be a virus
        j end_if_grid_primary_colour
    if_grid_primary_colour:
        is_pill(%grid) # check if its a pill
        bnez $v0 if_not_grid_primary_colour # if its a pill, then its not a virus
        addi $v0 $zero 1 #ow, it must be a virus
    end_if_grid_primary_colour:
    pop($t1)
.end_macro

# This function will reset %grid to black
.macro reset_grid(%grid)
    push($a3)
    push($v0)
    grid_to_offset(%grid)
    add $a3 $v0 $zero # Stores the offset value
    load_asset(asset_brack, $a3)
    pop($v0)
    pop($a3)
.end_macro
# This function will return the colour of the grid
# Param: grid number
# Returns in $v0:
# red: 0
# blue: 1
# yellow: 2
# else: 5
.macro get_grid_colour(%grid)
    push($t0)
    push($t1)
    grid_middle_offset(%grid) #Get the middle offset, which displays constant colour
    add $t0 $v0 $zero #store return in $t0
    lw $t1 ADDR_DSPL
    add $t0 $t1 $t0 # Stores the top left of the entire screen, plus the offset
    lw $t1 0( $t0 ) # Gets the value stored in memory, at that box

    addi $t0 $zero 0xD84060 #Colour code for red
    beq $t0 $t1 if_get_grid_colour_red
    addi $t0 $zero 0x60A0FF #Colour code for blue
    beq $t0 $t1 if_get_grid_colour_blue
    addi $t0 $zero 0xE8D020 #Colour code for yellow
    beq $t0 $t1 if_get_grid_colour_yellow
    j if_get_grid_colour_none

    if_get_grid_colour_red:
        addi $v0 $zero 0
        j end_grid_colour
    if_get_grid_colour_blue:
        addi $v0 $zero 1
        j end_grid_colour
    if_get_grid_colour_yellow:
        addi $v0 $zero 2
        j end_grid_colour
    if_get_grid_colour_none:
        addi $v0 $zero 5
        j end_grid_colour
    end_grid_colour:
    pop($t1)
    pop($t0)
.end_macro


# This function will rotate the value of the current pill:
# The rotation will swap the values of s0, and s1, st s0 < s1
.macro rotate()
    push($v0)
    push($a1)
    push($a2)
    push($t0)
    beqz $s2 if_rotate_pill_vertical
    j if_rotate_pill_horizontal
    if_rotate_pill_vertical: # going from vertical to horizontal
        collide_vert_rotate()  # check for rotation
        add $t0 $zero $v0
        bgtz $t0 if_rotate_pill_end  # non-zero return implies there is a collision
        get_grid_colour($s0)  # get the top pill colour
        add $a1 $zero $v0  # store top pill colour in $a1
        reset_grid($s0)  # remove the old pill segment
        addi $s0 $s0 10  # (x,y) => (x+1, y-1)
        draw_pill_segment($s0, $a1)  # draw segment in new position
        swap($s0 $s1)  # swap the index values of the segments
        addi $s2 $zero 1  # set the orientation of the pill to horizontal
        j if_rotate_pill_end
    if_rotate_pill_horizontal: # going from horizontal to vertical
        collide_horz_rotate()  # check for rotation
        add $t0 $zero $v0
        bgtz $t0 if_rotate_pill_end  # non-zero return implies there is a collision
        get_grid_colour($s1)  # get the right pill colour
        add $a1 $zero $v0  # store right pill colour in $a1
        get_grid_colour($s0)  # get the left pill colour
        add $a2 $zero $v0  # store left pill colour in $a2
        reset_grid($s0)  # remove old pill segments
        reset_grid($s1)
        subi $s1 $s1 1  # move right pill segment to the left by one
        subi $s0 $s0 9  # move left pill segment up by one
        draw_pill_segment($s0, $a2)  # draw the new pill segments
        draw_pill_segment($s1, $a1)
        add $s2 $zero $zero  # set the orientation of the pill to vertical
        j if_rotate_pill_end
    if_rotate_pill_end:
    pop($t0)
    pop($a2)
    pop($a1)
    pop($v0)
.end_macro

# This function will move the current pill, in the specificed direction
# The current grid of the pill is stored at $s0 $s1
# First this function will delete the pill at the current location, update the values of $s0 $s1, and redraw
# This function will repeat until a bottom collision return
.macro move_pill()
    push($t0)
    push($t1)
    push($t2)
    push($t3)
    push($a0)
    push($a1)
    push($a2)
    push($v0)
    move_pill_loop:
      add $t0 $zero $zero
      while_no_key_is_pressed:
          key_pressed() # Checks if a key has been pressed
          which_key($v0) # Will return which key is pressed
          move $t0 $v0 # Will store the value of which key is pressed
    
          addi $t1 $zero 1 # If pressed w, if_move_rotate
          beq $t0 $t1 if_move_rotate
    
          addi $t1 $zero 2 # If pressed a, move left
          beq $t0 $t1 if_move_left
    
          addi $t1 $zero 3 # If pressed s, move down
          beq $t0 $t1 if_move_down
    
          addi $t1 $zero 4 # If pressed d, move right
          beq $t0 $t1 if_move_right

          addi $t1 $zero 6 # If pressed p, pause
          beq $t0 $t1 if_pressed_pause
          
          potential_down_move: # all movements will jump back bere
          addi $t2 $t2 1

          li $v0 30
          syscall
          subu $a0 $a0 $s3
          addi $t3 $zero 4000
          div $t3 $t3 $s4
          sub $a0 $a0 $t3
          
          bgez $a0 if_timer_is_full_move # modify constant to change the delay
          j end_if_timer_is_full_move
          if_timer_is_full_move:
              curr_time_2()
              j if_move_down # force a move down
          end_if_timer_is_full_move:
          j while_no_key_is_pressed
          
      if_move_rotate:
          rotate()
          j potential_down_move
      if_move_left:
          beqz $s2 if_move_left_collision_vert
          j if_move_left_collision_horz
          
          if_move_left_collision_vert:
              collide_left($s0) #check if the top collides
              add $t0 $zero $v0 # value will be 4 with no collison 
              collide_left($s1) # check if bottom collides
              add $t0 $t0 $v0  
              beq $t0 8 end_if_move_left_collision # if no values are 8, no collision
              j potential_down_move # ow restart loop
          if_move_left_collision_horz:
              collide_left($s0) #check if the top collides
              add $t0 $zero $v0 # value will be 4 with no collison 
              beq $t0 4 end_if_move_left_collision
              j potential_down_move
          end_if_move_left_collision:
          get_grid_colour($s0)
          add $a2 $zero $v0
          reset_grid($s0)
          subi $s0 $s0 1
          draw_pill_segment($s0 $a2)
          
          get_grid_colour($s1)
          move $a2 $v0
          reset_grid($s1)
          subi $s1 $s1 1
          draw_pill_segment($s1 $a2)
          j potential_down_move
      if_move_right:
          beqz $s2 if_move_right_collision_vert
          j if_move_right_collision_horz
      
          if_move_right_collision_vert:
              collide_right($s0) #check if the top collides
              add $t0 $zero $v0 # value will be 4 with no collison 
              collide_right($s1) # check if bottom collides
              add $t0 $t0 $v0  
              beq $t0 8 end_if_move_right_collision # if no values are 8, no collision
              j potential_down_move # ow restart loop
          if_move_right_collision_horz:
              collide_right($s1) #check if the right collides
              add $t0 $zero $v0 # value will be 4 with no collison 
              beq $t0 4 end_if_move_right_collision
              j potential_down_move
          end_if_move_right_collision:
          get_grid_colour($s0)
          add $a2 $zero $v0
          get_grid_colour($s1)
          add $a1 $zero $v0
          reset_grid($s0)
          reset_grid($s1)
          addi $s0 $s0 1
          addi $s1 $s1 1
          draw_pill_segment($s0, $a2)
          draw_pill_segment($s1, $a1)
          j potential_down_move
      if_move_down:
          beqz $s2 if_move_down_collision_vert
          j if_move_down_collision_horz
          if_move_down_collision_vert:
              collide_bottom($s1) #check if the bottom collides
              add $t0 $zero $v0 # value will be 4 with no collison
              beq $t0 4 end_if_move_down_collision
              j end_move_pill_loop
          if_move_down_collision_horz:
              collide_bottom($s0)
              add $t0 $zero $v0
              collide_bottom($s1)
              add $t0 $t0 $v0
              beq $t0 8 end_if_move_down_collision # if no values are 8, no collision
              j end_move_pill_loop # ow draw new pill
          end_if_move_down_collision:
          get_grid_colour($s0)
          add $a2 $zero $v0
          get_grid_colour($s1)
          add $a1 $zero $v0
          reset_grid($s0)
          reset_grid($s1)
          addi $s0 $s0 9
          addi $s1 $s1 9
          draw_pill_segment($s0, $a2)
          draw_pill_segment($s1, $a1)
          j potential_down_move
      if_pressed_pause:
          push($s7)
          jal pause_loop
          j potential_down_move
      if_move_end:
      j move_pill_loop
      end_move_pill_loop:
      pop($v0)
      pop($a2)
      pop($a1)
      pop($a0)
      pop($t3)
      pop($t2)
      pop($t1)
      pop($t0)
.end_macro

# This function return the grouping number to its left (not including itself)
# Params:
# %segment : grid number for pill segment
# returns : final grouing number in $v0
.macro get_grouping_left(%grid)
    push($a0)
    push($t0)
    push($t1)
    push($t2)
    add $a0 $zero %grid #store the current grid in a0
    add $t2 $zero $zero # sets current amount as 0
    get_left_grouping_while_loop: # do while loop
      get_grid_colour($a0)
      add $t0 $zero $v0 # store current grid colour in $t0
      collide_left($a0) # gets the colour of the block to its left
      sub $t1 $t0 $v0 # subtracts current colour with itself
      beqz $t1 if_same_colour_left_collision # same colour value
      j end_left_grouping_while_loop
        if_same_colour_left_collision:
            addi $t2 $t2 1 # increase value of t2 by 1
            subi $a0 $a0 1 # move over to the next grid
            j get_left_grouping_while_loop # repeat the loop
    end_left_grouping_while_loop:
    add $v0 $zero $t2
    pop($t2)
    pop($t1)
    pop($t0)
    pop($a0)
.end_macro

# This function return the grouping number to its left (not including itself)
# Params:
# %segment : grid number for pill segment
# returns : final grouing number in $v0
.macro get_grouping_right(%grid)
    push($a0)
    push($t0)
    push($t1)
    push($t2)
    add $a0 $zero %grid #store the current grid in a0
    add $t2 $zero $zero # sets current amount as 0
    get_right_grouping_while_loop: # do while loop
      get_grid_colour($a0)
      add $t0 $zero $v0 # store current grid colour in $t0
      collide_right($a0) # gets the colour of the block to its right
      sub $t1 $t0 $v0 # subtracts current colour with itself
      beqz $t1 if_same_colour_right_collision # same colour value
      j end_right_grouping_while_loop
        if_same_colour_right_collision:
            addi $t2 $t2 1 # increase value of t2 by 1
            addi $a0 $a0 1 # move over to the next grid
            j get_right_grouping_while_loop # repeat the loop
    end_right_grouping_while_loop:
    add $v0 $zero $t2
    pop($t2)
    pop($t1)
    pop($t0)
    pop($a0)
.end_macro

.macro get_grouping_top(%grid)
    push($a0)
    push($t0)
    push($t1)
    push($t2)
    add $a0 $zero %grid #store the current grid in a0
    add $t2 $zero $zero # sets current amount as 0
    get_top_grouping_while_loop:
        get_grid_colour($a0)
        add $t0 $zero $v0  # store current grid color in $t0
        collide_top($a0)  # get colour of block above
        sub $t1 $t0 $v0  # compare color above to curr color 
        beqz $t1 if_same_colour_top_collision  # same color
        j end_top_grouping_while_loop
            if_same_colour_top_collision:
                addi $t2 $t2 1  # increment t2
                subi $a0 $a0 9  # move up by one
                j get_top_grouping_while_loop
    end_top_grouping_while_loop:
    add $v0 $zero $t2  # store return value as length of grouping
    pop($t2)
    pop($t1)
    pop($t0)
    pop($a0)
.end_macro

.macro get_grouping_bottom(%grid)
    push($a0)
    push($t0)
    push($t1)
    push($t2)
    add $a0 $zero %grid #store the current grid in a0
    add $t2 $zero $zero # sets current amount as 0
    get_bottom_grouping_while_loop:
        get_grid_colour($a0)
        add $t0 $zero $v0  # store current grid color in $t0
        collide_bottom($a0)  # get colour of block below
        sub $t1 $t0 $v0  # compare color below to curr color 
        beqz $t1 if_same_colour_bottom_collision  # same color
        j end_bottom_grouping_while_loop
            if_same_colour_bottom_collision:
                addi $t2 $t2 1  # increment t2
                addi $a0 $a0 9  # move down by one
                j get_bottom_grouping_while_loop
    end_bottom_grouping_while_loop:
    add $v0 $zero $t2  # store return value as length of grouping
    pop($t2)
    pop($t1)
    pop($t0)
    pop($a0)
.end_macro

# this function will compute if theres a grouping valie > 3. If there is, itll be deleted.
# This function will return a non-zero-number, if there was a removal.
.macro total_grouping_removal()
    push($t0)
    push($t8)
    push($t9)
    push($t3)

    
    # LOGIC FOR S0 HORIZONTAL
    add $t3 $t3 $zero #set starting return value
    get_grouping_left($s0)
    add $t9 $zero $v0 #store number of same colour pills to the left
    get_grouping_right($s0)
    add $t8 $zero $v0 #store number of same colour pills to the right
    add $t8 $t8 $t9 # add these 2 rows
    bge $t8 3 if_grouping_row_s0 # If atleast 4 are touching
    j end_if_grouping_row_s0 # ow. skip over logic
    
    if_grouping_row_s0:
        sub $t0 $s0 $t9 # move to the left most pill
        remove_grouping_row_loop_s0:
            grid_to_offset($t0)
            load_asset(asset_white_pill $v0)
            sleep(20)
            reset_grid($t0)
            addi $t0 $t0 1 # move to the right one pill
            subi $t8 $t8 1 # decrease remaining number of pills
            bge $t8 $zero remove_grouping_row_loop_s0
            addi $t3 $zero 1 #set return value
            j end_of_s0_grouping_logic
    end_if_grouping_row_s0:


    # LOGIC FOR S0 VERTICAL
    get_grouping_top($s0)  # store number of same colour pills above
    add $t9 $zero $v0  # store length of top grouping in $t9
    get_grouping_bottom($s0)  # store number of same colour pills below
    add $t8 $zero $v0  # store length of top grouping in $t8
    add $t8 $t8 $t9  # add two rows together
    bge $t8 3 if_grouping_col_s0  # if >= 4 in a row
    j end_if_grouping_col_s0  # else

    
    if_grouping_col_s0:
        addi $t0 $zero 9  # store 9 in $t0
        mul $t9 $t9 $t0  # store 9*len(topgrouping) in $t9
        sub $t0 $s0 $t9  # move up 9 pills
        remove_grouping_col_loop_s0:
            grid_to_offset($t0)
            load_asset(asset_white_pill $v0)
            sleep(20)
            reset_grid($t0)
            addi $t0 $t0 9  # move down by one
            subi $t8 $t8 1  # decrease remaining by one
            bge $t8 $zero remove_grouping_col_loop_s0
            addi $t3 $zero 1  # set return value
            j end_of_s0_grouping_logic
        end_if_grouping_col_s0:

    end_of_s0_grouping_logic:
    # LOGIC FOR S1 HORIZONTAL
    get_grouping_left($s1)
    add $t9 $zero $v0 #store number of same colour pills to the left
    get_grouping_right($s1)
    add $t8 $zero $v0 #store number of same colour pills to the right
    add $t8 $t8 $t9 # add these 2 rows
    bge $t8 3 if_grouping_row_s1 # If atleast 4 are touching
    j end_if_grouping_row_s1 # ow. skip over logic
    
    if_grouping_row_s1:
        sub $t0 $s1 $t9 # move to the left most pill
        remove_grouping_row_loop_s1:
            grid_to_offset($t0)
            load_asset(asset_white_pill $v0)
            sleep(20)
            reset_grid($t0)
            addi $t0 $t0 1 # move to the right one pill
            subi $t8 $t8 1 # decrease remaining number of pills
            bge $t8 $zero remove_grouping_row_loop_s1
            addi $t3 $zero 1  # set return value
            j end_of_total_grouping
    end_if_grouping_row_s1:
    
    # LOGIC FOR S1 VERTICAL
    get_grouping_top($s1)  # store number of same colour pills above
    add $t9 $zero $v0  # store length of top grouping in $t9
    get_grouping_bottom($s1)  # store number of same colour pills below
    add $t8 $zero $v0  # store length of top grouping in $t8
    add $t8 $t8 $t9  # add two rows together
    bge $t8 3 if_grouping_col_s1  # if >= 4 in a row
    j end_if_grouping_col_s1  # else

    
    if_grouping_col_s1:
        addi $t0 $zero 9  # store 9 in $t0
        mul $t9 $t9 $t0  # store 9*len(topgrouping) in $t9
        sub $t0 $s1 $t9  # move up 9 pills
        remove_grouping_col_loop_s1:
            grid_to_offset($t0)
            load_asset(asset_white_pill $v0)
            sleep(20)
            reset_grid($t0)
            addi $t0 $t0 9  # move down by one
            subi $t8 $t8 1  # decrease remaining by one
            bge $t8 $zero remove_grouping_col_loop_s1
            addi $t3 $zero 1  # set return value
            j end_of_total_grouping
        end_if_grouping_col_s1:
    
    
    end_of_total_grouping:
    add $s0 $zero $zero
    add $s1 $zero $zero
    add $v0 $zero $t3    
    pop($t3)
    pop($t9)
    pop($t8)
    pop($t0)
.end_macro

# params:
# starting will be the grid to start the row checking
# Once this function finds one pill which should drop. it will return 1, and run again.
.macro gravity_detection()
    push($t0)
    push($t2)
    push($t8)
    add $t8 $zero $zero # sets each element of our bit set to be 0
    addi $a0 $zero 161 # this will be the current grid
    add $t0 $zero $zero # this will be the lsb of the bitmap
    
    gravity_bottom_row_loop:
        get_grid_colour($a0) # checks if the current grid is a pill or virus
        bne $v0 5 if_bottom_row_is_coloured
        j end_if_bottom_row_is_coloured
        if_bottom_row_is_coloured:
            setbit($t8 $t0) # set that bit to be a 1
            
            collide_top($a0)
            bge $v0 3 end_if_bottom_row_top_collision 
            j if_bottom_row_top_collision # if there is a collision above, set that bit to be 1
            if_bottom_row_top_collision:
                addi $t2 $t0 9
                setbit($t8 $t2)
                # addi $t2 $a0 9 # get one row up
                # is_virus($t2)
                # beq $v0 1 end_if_bottom_row_is_coloured # if the one above is a virus, do not set the left and the right
            end_if_bottom_row_top_collision:
              
            subi $t2 $a0 9 # move up 1 row
            collide_left($t2)
            bge $v0 3 end_if_bottom_row_left_collision # if there is a collision left, set that bit to be 1
            j if_bottom_row_left_collision
            if_bottom_row_left_collision:
                addi $t2 $t0 10
                setbit($t8 $t2) # set that bit to be 1
            end_if_bottom_row_left_collision:


            subi $t2 $a0 9 # move up 1 row
            collide_right($t2)
            bge $v0 3 end_if_bottom_row_right_collision # if there is a collision left, set that bit to be 1
            j if_bottom_row_right_collision
            if_bottom_row_right_collision:
                addi $t2 $t0 8
                setbit($t8 $t2) # set that bit to be 1
            end_if_bottom_row_right_collision:
              
        end_if_bottom_row_is_coloured:
        subi $a0 $a0 1
        addi $t0 $t0 1
        beq $t0 9 end_gravity_bottom_row_loop
        j gravity_bottom_row_loop
    end_gravity_bottom_row_loop:

    while_gravity_on_row:
        srl $t8 $t8 9 # Shift the bitmap over by 9 units
        add $t0 $zero $zero #reset iter variable to be 0
        gravity_2_row_loop:
            is_virus($a0) # if this grid is a virus, set that value to be one
            beq $v0 1 if_row_2_is_virus
            j end_if_row_2_is_virus
            if_row_2_is_virus:
                setbit($t8 $t0)
            end_if_row_2_is_virus:
    
            getbit($t8 $t0) # get the current bit.
          
            beq $v0 1 if_row_2_bit_is_one
            j if_row_2_bit_is_zero
            if_row_2_bit_is_one:
    
    
              
                collide_top($a0)
                bge $v0 3 end_if_row_2_bit_is_value
                j if_2_row_top_collision # if there is a collision above, set that bit to be 1
                if_2_row_top_collision:
                    addi $t2 $t0 9
                    setbit($t8 $t2)
                    # addi $t2 $a0 9 # get one row up
                    # is_virus($t2)
                    # beq $v0 1 end_if_row_2_bit_is_value # if the one above is a virus, do not set the left and the right
                end_if_2_row_top_collision:
                  
                subi $t2 $a0 9 # move up 1 row
                collide_left($t2)
                bge $v0 3 end_if_2_row_left_collision # if there is a collision left, set that bit to be 1
                j if_2_row_left_collision
                if_2_row_left_collision:
                    addi $t2 $t0 10
                    setbit($t8 $t2) # set that bit to be 1
                end_if_2_row_left_collision:
    
    
                subi $t2 $a0 9 # move up 1 row
                collide_right($t2)
                bge $v0 3 end_if_2_row_right_collision # if there is a collision left, set that bit to be 1
                j if_2_row_right_collision
                if_2_row_right_collision:
                    addi $t2 $t0 8
                    setbit($t8 $t2) # set that bit to be 1
                end_if_2_row_right_collision:
    
    
                
                j end_if_row_2_bit_is_value
            if_row_2_bit_is_zero: # if that value is 0
                is_pill($a0) # Check if the current bit is 0
                beq $v0 1 if_row_2_bit_is_pill
                j end_if_row_2_bit_is_value # ow. this value should fall
                if_row_2_bit_is_pill: # if this is the case, the pill should fall
                    # reset_grid($a0) #TODO: Change this logic to drop the pill down
                    drop_pixel($a0)
                    addi $v0 $zero 1 # set the return value to 1
                    j end_of_gravity_function
            end_if_row_2_bit_is_value:
            subi $a0 $a0 1
            addi $t0 $t0 1
            beq $t0 9 end_gravity_2_row_loop
            j gravity_2_row_loop
        end_gravity_2_row_loop:
        ble $a0 0 end_gravity_on_row
        j while_gravity_on_row
        add $v0 $zero $zero # set the return value to be 0
    end_gravity_on_row:
    
    end_of_gravity_function:
    pop($t8)
    pop($t2)
    pop($t0)
.end_macro


# drop the pill at index %grid to the first bottom collision
.macro drop_pixel(%grid)
    push($t1)
    add $a0 %grid $zero  # $a0 = final grid index of %grid
    get_grid_colour($a0)
    add $a1 $zero $v0  # store colour of %grid at $a1
    reset_grid($a0)
    collide_bottom_loop:
        addi $a0 $a0 9  # move down a row
        collide_bottom($a0)
        subi $t3 $v0 4  # if no collision, t3 is 0
        grid_to_offset($a0)
        load_asset(asset_white_pill $v0)
        sleep(20)
        reset_grid($a0)
        beq $t3 $zero collide_bottom_loop
    draw_pill_segment($a0 $a1)
    add $s0 $zero $a0  # set $s0 to be the location of this pill segment
    pop($t1)
.end_macro

.macro render_red_virus()
    push($t0)
    push($t1)
    get_viruses()
    addi $t0 $zero 0
    getbit($s5 $t0)
    beq $v0 $zero render_red_knocked

    addi $t0 $zero 0
    beq $s6 $t0 render_red_frame_1
    addi $t0 $t0 1
    beq $s6 $t0 render_red_frame_2
    addi $t0 $t0 1
    beq $s6 $t0 render_red_frame_3
    addi $t0 $t0 1
    beq $s6 $t0 render_red_frame_4
    addi $t0 $zero 0
    render_red_frame_1:
        load_asset(asset_red_virus_1, $zero)
        j render_red_frame_end
    render_red_frame_2:
        load_asset(asset_red_virus_2, $zero)
        j render_red_frame_end
    render_red_frame_3:
        load_asset(asset_red_virus_3, $zero)
        j render_red_frame_end
    render_red_frame_4:
        load_asset(asset_red_virus_4, $zero)
        j render_red_frame_end

    render_red_knocked:
    addi $t0 $zero 0
    beq $s6 $t0 render_red_frame_5
    addi $t0 $t0 1
    beq $s6 $t0 render_red_frame_6
    addi $t0 $t0 1
    beq $s6 $t0 render_red_frame_5
    addi $t0 $t0 1
    beq $s6 $t0 render_red_frame_6
    addi $t0 $zero 0

    render_red_frame_5:
        load_asset(asset_red_virus_5, $zero)
        j render_red_frame_end
    render_red_frame_6:
        load_asset(asset_red_virus_6, $zero)
        j render_red_frame_end
        
    render_red_frame_end:
    pop($t1)
    pop($t0)
.end_macro

.macro render_yellow_virus()
    push($t0)
    push($t1)
    get_viruses()
    addi $t0 $zero 2
    getbit($s5 $t0)
    beq $v0 $zero render_yellow_knocked
    addi $t0 $zero 0
    beq $s6 $t0 render_yellow_frame_1
    addi $t0 $t0 1
    beq $s6 $t0 render_yellow_frame_2
    addi $t0 $t0 1
    beq $s6 $t0 render_yellow_frame_3
    addi $t0 $t0 1
    beq $s6 $t0 render_yellow_frame_4
    addi $t0 $zero 0
    render_yellow_frame_1:
        load_asset(asset_yellow_virus_1, $zero)
        j render_yellow_frame_end
    render_yellow_frame_2:
        load_asset(asset_yellow_virus_2, $zero)
        j render_yellow_frame_end
    render_yellow_frame_3:
        load_asset(asset_yellow_virus_3, $zero)
        j render_yellow_frame_end
    render_yellow_frame_4:
        load_asset(asset_yellow_virus_4, $zero)
        j render_yellow_frame_end
    render_yellow_knocked:
    addi $t0 $zero 0
    beq $s6 $t0 render_yellow_frame_5
    addi $t0 $t0 1
    beq $s6 $t0 render_yellow_frame_6
    addi $t0 $t0 1
    beq $s6 $t0 render_yellow_frame_5
    addi $t0 $t0 1
    beq $s6 $t0 render_yellow_frame_6
    addi $t0 $zero 0
    render_yellow_frame_5:
        load_asset(asset_yellow_virus_5, $zero)
        j render_yellow_frame_end
    render_yellow_frame_6:
        load_asset(asset_yellow_virus_6, $zero)
        j render_yellow_frame_end
    render_yellow_frame_end:
    pop($t1)
    pop($t0)
 

.end_macro

.macro render_blue_virus()
    push($t0)
    push($t1)
    get_viruses()
    addi $t0 $zero 1
    getbit($s5 $t0)
    beq $v0 $zero render_blue_knocked

    addi $t0 $zero 0
    beq $s6 $t0 render_blue_frame_1
    addi $t0 $t0 1
    beq $s6 $t0 render_blue_frame_2
    addi $t0 $t0 1
    beq $s6 $t0 render_blue_frame_3
    addi $t0 $t0 1
    beq $s6 $t0 render_blue_frame_4
    addi $t0 $zero 0
    render_blue_frame_1:
        load_asset(asset_blue_virus_1, $zero)
        j render_blue_frame_end
    render_blue_frame_2:
        load_asset(asset_blue_virus_2, $zero)
        j render_blue_frame_end
    render_blue_frame_3:
        load_asset(asset_blue_virus_3, $zero)
        j render_blue_frame_end
    render_blue_frame_4:
        load_asset(asset_blue_virus_4, $zero)
        j render_blue_frame_end

    render_blue_knocked:
    addi $t0 $zero 0
    beq $s6 $t0 render_blue_frame_5
    addi $t0 $t0 1
    beq $s6 $t0 render_blue_frame_6
    addi $t0 $t0 1
    beq $s6 $t0 render_blue_frame_5
    addi $t0 $t0 1
    beq $s6 $t0 render_blue_frame_6
    addi $t0 $zero 0

    render_blue_frame_5:
        load_asset(asset_blue_virus_5, $zero)
        j render_blue_frame_end
    render_blue_frame_6:
        load_asset(asset_blue_virus_6, $zero)
        j render_blue_frame_end
        
    render_blue_frame_end:
    pop($t1)
    pop($t0)
.end_macro

.macro render_ricardo()
    push($t0)
    addi $t0 $zero 0
    beq $s6 $t0 render_ricardo_frame_1
    addi $t0 $t0 2
    beq $s6 $t0 render_ricardo_frame_2
    addi $t0 $zero 0
    render_ricardo_frame_1:
        load_asset(asset_clear_ricardo, $zero)
        load_asset(asset_ricardo_1, $zero)
        j render_ricardo_end
    render_ricardo_frame_2:
        load_asset(asset_ricardo_2, $zero)
        j render_ricardo_end
    render_ricardo_end:
    pop($t0)
.end_macro

.macro render_frame()
    push($t1)
    addi $t1 $zero 4
    bne $s6 $t1 end_reset_s6
    add $s6 $zero $zero
    end_reset_s6:
    load_asset(asset_magnifying_glass, $zero)
    render_red_virus()
      render_blue_virus()
    render_yellow_virus()
    render_ricardo()
    addi $s6 $s6 1
    pop($t1)
render_frame_end:
.end_macro

.macro curr_time()
    li $v0 30
    syscall
    add $s7 $a0 $zero  # store current time in milliseconds in s7
.end_macro

.macro curr_time_2()
    li $v0 30
    syscall
    add $s3 $a0 $zero  # store current time in milliseconds in s7
.end_macro

.macro is_next_frame()
    li $v0 30
    syscall
    subu $a1 $a0 $s7  # a1 = a0 - s7
    subi $a1 $a1 500
    bgtz $a1 render_next_frame
    j no_render_occurred
    render_next_frame:
        curr_time()
        render_frame()
    no_render_occurred:
.end_macro

# This function will detect which colour viruses are still alive, and store that value $s5
# Bit 0 : 1 if red virus exits 0 ow
# Bit 1 : 1 if blue virus exits 0 ow
# Bit 2 : 1 if yellow virus exits 0 ow
.macro get_viruses()
    push($v0)
    addi $a0 $zero 161 # 161 to 63 are grids where a virus can spawn
    add $s5 $zero $zero # reset the bitmap to be 0
    check_for_virus_loop:
        is_virus($a0)
        beq $v0 $zero end_if_grid_is_virus # if not a virus
        if_grid_is_virus:
            get_grid_colour($a0)
            setbit($s5 $v0) # set that bit to 1
        end_if_grid_is_virus:
        subi $a0 $a0 1
        ble $a0 63 end_check_for_virus_loop # end the loop
        j check_for_virus_loop
    end_check_for_virus_loop:
    pop($v1)
.end_macro

addi $s4 $zero 4
main:
    #load the inital values
    add $s6 $zero $zero
    addi $s5 $zero 1
    add $s7 $zero $zero
    load_asset(asset_background, $zero)
    load_asset(asset_ricardo_1, $zero)
    draw_starter_virus()
    curr_time()
    curr_time_2()
game_loop:
    get_viruses()
    beqz $s5 win_loop # if there are no viruses left, end the game
    pill_creation()
    move_pill()
    while_there_is_possible_removal:
        total_grouping_removal()
        gravity_detection()
        bne $v0 $zero while_there_is_possible_removal # If we move something down, check for total grouping
    # 1b. Check which key has been pressed
    # 2a. Check for collisions
	# 2b. Update locations (capsules)
	# 3. Draw the screen
	# 4. Sleeps

    # 5. Go back to Step 1

    j game_loop
  
.macro fade_to_black()
    push($t0)
    push($t1)
    push($t2)
    push($t3)
    push($t4)
    push($t5)
    push($t6)
    push($t7)
    push($a0)
    push($a1)

    li $t0, 0                 # Pixel counter (0 to 65535)
    li $t1, 65536             # Total number of pixels
    lw $t2, ADDR_DSPL         # $t2 = base display address

    li $t6, 0                 # Fade step (0 to 3)

fade_loop_outer:
    li $t0, 0                 # Reset pixel counter
fade_loop_inner:
    mul $t3, $t0, 4           # Offset = pixel index * 4
    add $t4, $t2, $t3         # $t4 = address of pixel

    lw $t5, 0($t4)            # Load current pixel color

    
    srl $a0, $t5, 16          # R = (pixel >> 16) & 0xFF
    andi $a0, $a0, 0xFF
    srl $a1, $t5, 8           # G = (pixel >> 8) & 0xFF
    andi $a1, $a1, 0xFF
    andi $t7, $t5, 0xFF       # B = pixel & 0xFF

    beq $t6, 0, fade_step_1
    beq $t6, 1, fade_step_2
    beq $t6, 2, fade_step_3
    beq $t6, 3, fade_step_4

fade_step_1:  # 75%
    mul $a0, $a0, 3
    div $a0, $a0, 4
    mul $a1, $a1, 3
    div $a1, $a1, 4
    mul $t7, $t7, 3
    div $t7, $t7, 4
    j finish_fade_step

fade_step_2:  # 50%
    srl $a0, $a0, 1
    srl $a1, $a1, 1
    srl $t7, $t7, 1
    j finish_fade_step

fade_step_3:  # 25%
    srl $a0, $a0, 2
    srl $a1, $a1, 2
    srl $t7, $t7, 2
    j finish_fade_step

fade_step_4:  # 0%
    li $a0, 0
    li $a1, 0
    li $t7, 0

finish_fade_step:
    sll $a0, $a0, 16
    sll $a1, $a1, 8
    or  $a0, $a0, $a1
    or  $a0, $a0, $t7

    sw $a0, 0($t4)            # Store faded pixel
    addi $t0, $t0, 1
    blt $t0, $t1, fade_loop_inner

    sleep(200)                
    addi $t6, $t6, 1
    blt $t6, 4, fade_loop_outer

    pop($a1)
    pop($a0)
    pop($t7)
    pop($t6)
    pop($t5)
    pop($t4)
    pop($t3)
    pop($t2)
    pop($t1)
    pop($t0)
.end_macro

lose_setup:
  fade_to_black()
  sleep(750)
  j lose_loop
  
lose_loop:
  load_asset(asset_youlose, $zero)
  add $s7 $zero -1
  key_pressed() # Change to be a specific key is pressed
  which_key($v0)
  bne $v0 5 lose_loop # if a key has been pressed, restart the game
  load_asset(asset_clearscreen, $zero)
  addi $s4 $zero 4
  j main


pause_loop:
  load_asset(asset_gamepause, $zero)
  addi $s7 $zero -1
  key_pressed() # Change to be a specific key is pressed
  which_key($v0)
  bne $v0 6 pause_loop
  load_asset(asset_pauseclear, $zero)
  pop($s7)
  jr $ra


win_loop:
  fade_to_black()
  sleep(100)
  addi $s4 $s4 3
  j main