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

	
/* global variables */
volatile int pixel_buffer_start; 
int COLORS[10] = {WHITE, YELLOW, RED, GREEN, BLUE, CYAN, MAGENTA, GREY, PINK, ORANGE};


// function declaration:
void clear_screen();
void draw_line(int x0, int y0, int x1, int y1, short int color);
void wait_for_vsync();
void plot_pixel(int x, int y, short int line_color);


/*****************************************************************************************/
int main(void)
{
    volatile int * pixel_ctrl_ptr = (int *)0xFF203020;
    /* Read location of the pixel buffer from the pixel buffer controller */
    pixel_buffer_start = *pixel_ctrl_ptr;
	
	/* Random number generator */
	time_t t1; // declare time variable
	/* define the random number generator */  
    srand ( (unsigned) time (&t1)); // pass the srand() parameter  
	
	/* Motion control vectors */ 
	int DOWN = 1; 
	int UP = -1;
	
	int y_coor = 0;
	int  color = 0;
	
    clear_screen();
	
    draw_line(30, y_coor, 289, y_coor, YELLOW);
	
	while(TRUE){
		while(y_coor < RESOLUTION_Y - 1){
			draw_line(30, y_coor, 289, y_coor, 0x0);

			y_coor = y_coor + DOWN;
			color = COLORS[rand() % 10];

			draw_line(30, (y_coor), 289, (y_coor), color);
			wait_for_vsync();
		}
		while(y_coor > 0){
			draw_line(30, y_coor, 289, y_coor, 0x0);

			y_coor = y_coor + UP;
			color = COLORS[rand() % 10];

			draw_line(30, (y_coor), 289, (y_coor), color);
			wait_for_vsync();
		}
	}
}
/*****************************************************************************************/


// function definition:

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
