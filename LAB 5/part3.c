/* This files provides address values that exist in the system */

#define SDRAM_BASE            0xC0000000
#define FPGA_ONCHIP_BASE      0xC8000000
#define FPGA_CHAR_BASE        0xC9000000

/* Cyclone V FPGA devices */
#define LEDR_BASE             0xFF200000
#define HEX3_HEX0_BASE        0xFF200020
#define HEX5_HEX4_BASE        0xFF200030
#define SW_BASE               0xFF200040
#define KEY_BASE              0xFF200050
#define TIMER_BASE            0xFF202000
#define PIXEL_BUF_CTRL_BASE   0xFF203020
#define CHAR_BUF_CTRL_BASE    0xFF203030

/* VGA colors */
#define WHITE 0xFFFF
#define YELLOW 0xFFE0
#define RED 0xF800
#define GREEN 0x07E0
#define BLUE 0x001F
#define CYAN 0x07FF
#define MAGENTA 0xF81F
#define GREY 0xC618
#define PINK 0xFC18
#define ORANGE 0xFC00

#define ABS(x) (((x) > 0) ? (x) : -(x))

/* Screen size. */
#define RESOLUTION_X 320
#define RESOLUTION_Y 240

/* Constants for animation */
#define BOX_LEN 2
#define NUM_BOXES 8

#define FALSE 0
#define TRUE 1

#include <stdlib.h>
#include <stdio.h>
#include <stdbool.h>
#include <time.h> // use time.h header file to use time  

// function declaration:
void plot_pixel(int x, int y, short int line_color);
void clear_screen();
void draw_line(int x0, int y0, int x1, int y1, short int color);
void wait_for_vsync();
void plot_box(int x0, int y0, short int color);

volatile int pixel_buffer_start; // global variable
int COLORS[10] = { WHITE, YELLOW, RED, GREEN, BLUE, CYAN, MAGENTA, GREY, PINK, ORANGE };
int randomMov[2] = { -1, 1 };

// Begin part3.c code for Lab 7
/*****************************************************************************************/
int main(void)
{
    volatile int * pixel_ctrl_ptr = (int *)0xFF203020;
    
	// declare other variables
	time_t t1; // declare time variable
	
	/* define the random number generator */
    srand ((unsigned) time (&t1)); // pass the srand() parameter  
	
    // initialize location and direction of boxes
	int boxes[8]           = {0, 1, 2, 3, 4, 5, 6, 7};
	int x_box[8]           = {};
	int y_box[8]           = {};
	int dx_box[8]          = {};
	int dy_box[8]          = {};
	short int color_box[8] = {};
	int preX[8]            = {};
	int preY[8]            = {};         
	
	for(int index = 0; index < 8; ++index){
		x_box[index]     = rand()%(RESOLUTION_X-5);   // 0~314
		y_box[index]     = rand()%(RESOLUTION_Y-5);   // 0~234
		dx_box[index]    = randomMov[rand() % 2];     // -1, 1
		dy_box[index]    = randomMov[rand() % 2];     // -1, 1
		color_box[index] = COLORS[rand() % 10];
	}
	
    /* set front pixel buffer to start of FPGA On-chip memory */
    *(pixel_ctrl_ptr + 1) = 0xC8000000; // first store the address in the back buffer
	
    /* now, swap the front/back buffers, to set the front buffer location */
    wait_for_vsync();
    
	/* initialize a pointer to the pixel buffer, used by drawing functions */
    pixel_buffer_start = *pixel_ctrl_ptr;  // pixel_buffer_start now points to the back buffer
    clear_screen(); // pixel_buffer_start points to the pixel buffer
    
	/* set back pixel buffer to start of SDRAM memory */
    *(pixel_ctrl_ptr + 1) = 0xC0000000;
    pixel_buffer_start = *(pixel_ctrl_ptr + 1); // we draw on the back buffer
    clear_screen(); // pixel_buffer_start points to the pixel buffer
	

	while (TRUE)
    {

		/* Erase any boxes and lines that were drawn in the last iteration */
		for(int index = 0; index < 8; ++index){
			plot_box(preX[index], preY[index], 0x0);
			draw_line(preX[index]+3, 
					  preY[index]+3, 
					  preX[(index+1)%8]+3, 
					  preY[(index+1)%8]+3, 
					  0x0);
		}
		
        // code for updating the locations of boxes (not shown)
		for(int index = 0; index < 8; ++index){
			preX[index] = x_box[index];
			preY[index] = y_box[index];
			x_box[index] += dx_box[index];
			y_box[index] += dy_box[index];
			
			/* Check for "edge of screen" */
			if (x_box[index] == 0 || x_box[index] == 314){
				dx_box[index] *= -1;
			}
			if (y_box[index] == 0 || y_box[index] == 234){
				dy_box[index] *= -1;
			}
		}
		
		// code for drawing the boxes and lines (not shown)
		for(int index = 0; index < 8; ++index){
			plot_box(x_box[index], y_box[index], color_box[index]);
			draw_line(x_box[index]+3, 
					  y_box[index]+3, 
					  x_box[(index+1)%8]+3, 
					  y_box[(index+1)%8]+3, 
					  color_box[index]);
		}

        wait_for_vsync(); // swap front and back buffers on VGA vertical sync
        pixel_buffer_start = *(pixel_ctrl_ptr + 1); // new back buffer -> b/c we always use the back pixel buffer to edit any changes
    }
}

/*****************************************************************************************/

// code for subroutines (not shown)

/* F0     : plot a 1x1 pixel box  
*  input  : x_coor, y_coor, color
*  output : to achieve double buffering
*/
void plot_pixel(int x, int y, short int line_color)
{
    *(short int *)(pixel_buffer_start + (y << 10) + (x << 1)) = line_color;
}


/* F1     : clears the screen to black (0x0)
*  input  : void
*  output : draw the entire screen to black
*/
void clear_screen(){
	for(int x = 0; x < RESOLUTION_X; x++){
		for(int y = 0; y < RESOLUTION_Y; y++){
			plot_pixel(x, y, 0x0);
		}
	}
}


/* F2     : draws the line we want
*  input  : x_start, y_start, x_end, y_end, color
*  output : draw the entire screen to black
*/
void draw_line(int x0, int y0, int x1, int y1, short int color){
	bool is_steep = abs(y1 - y0) > abs(x1 - x0);
	
	
	if(is_steep){
		int temp = 0;
		
		// swap (x0, y0)
		temp = x0;  x0 = y0;  y0 = temp;
		
		// swap (x1, y1)
		temp = x1;  x1 = y1;  y1 = temp;
	}
	
	if(x0 > x1){
		int temp = 0;
		
		// swap (x0, x1)
		temp = x0;  x0 = x1;  x1 = temp;
		
		// swap (y0, y1)
		temp = y0;  y0 = y1;  y1 = temp;
	}
	
	int deltax = x1 - x0;
	int deltay = abs(y1 - y0);
	int error = -(deltax / 2);
	int y = y0;
	int y_step = 0;
	
	if(y0 < y1) { y_step = 1; } else { y_step = -1; }
	
	for(int x = x0; x < x1; x++){
		if(is_steep){
			plot_pixel(y, x, color);
		}
		else{
			plot_pixel(x, y, color);
		}
		
		error = error + deltay;
		
		if(error > 0){
			y = y + y_step;
			error = error - deltax;
		}
	}
}


/* F3     : synchronizing with the VGA controller  
*  input  : void
*  output : to achieve double buffering
*/
void wait_for_vsync(){
	volatile int* pixel_ctrl_ptr = 0xFF203020;  // pixel controller
	register int status;
	
	*pixel_ctrl_ptr = 1;  // writing a one into the buffer controller register
	                      // to start the synchronization process
	
	status = *(pixel_ctrl_ptr +3);  // read status register, at address oxFF20302C
	while((status & 0x01) != 0){
		status = *(pixel_ctrl_ptr + 3);
	}
}

/* F4     : plot a 2x2 square box
*  input  : x_start, y_start, color
*  output : a colored 2x2 square box within the bound of screen
*/
void plot_box(int x0, int y0, short int color){
	for(int x = x0; x < (x0 + 7); ++x){
		for (int y = y0; y < (y0 + 7); ++y){
			plot_pixel(x, y, color);
		}
	}
}
