#include <assert.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

bool mouse_connected = false;
#include "../src/gui/Graphics.h"

static uint32_t readPixel(int x, int y)
{
  uint32_t pixel = 0;
  memcpy(&pixel, fbp + (size_t)y * screenLineLength + (size_t)x * screenPixelBytes,
         screenPixelBytes);
  return pixel;
}

static void exerciseFormat(unsigned int bits, unsigned int stride)
{
  struct fb_var_screeninfo vinfo = {0};
  struct fb_fix_screeninfo finfo = {0};
  vinfo.xres = 800;
  vinfo.yres = 480;
  vinfo.bits_per_pixel = bits;
  if (bits == 16)
  {
    vinfo.red = (struct fb_bitfield){ .offset = 11, .length = 5 };
    vinfo.green = (struct fb_bitfield){ .offset = 5, .length = 6 };
    vinfo.blue = (struct fb_bitfield){ .offset = 0, .length = 5 };
  }
  else
  {
    vinfo.red = (struct fb_bitfield){ .offset = 16, .length = 8 };
    vinfo.green = (struct fb_bitfield){ .offset = 8, .length = 8 };
    vinfo.blue = (struct fb_bitfield){ .offset = 0, .length = 8 };
    vinfo.transp = (struct fb_bitfield){ .offset = 24, .length = 8 };
  }
  finfo.line_length = stride;
  finfo.smem_len = stride * vinfo.yres;
  assert(configureFramebuffer(&vinfo, &finfo));

  fbp = calloc(1, screenSize);
  assert(fbp != NULL);
  setPixel(0, 0, 255, 0, 0);
  setPixel(799, 479, 0, 0, 255);
  assert(readPixel(0, 0) == (bits == 16 ? 0xf800u : 0xffff0000u));
  assert(readPixel(799, 479) == (bits == 16 ? 0x001fu : 0xff0000ffu));
  assert(fbp[800 * screenPixelBytes] == 0);  // Row padding is untouched.

  rectangle(0, 0, 1, 1, 0, 255, 0);
  assert(readPixel(0, 479) == (bits == 16 ? 0x07e0u : 0xff00ff00u));
  setBackColour(0, 0, 255);
  clearScreen();
  assert(readPixel(400, 240) == (bits == 16 ? 0x001fu : 0xff0000ffu));

  mfbp = calloc(1, screenSize);
  cfbp = calloc(1, screenSize);
  assert(mfbp != NULL && cfbp != NULL);
  mouse_connected = true;
  refreshMouseBackground();
  draw_cursor2(100, 100);
  assert(memcmp(mfbp, fbp, screenSize) != 0);
  mouse_connected = false;
  free(mfbp);
  free(cfbp);
  mfbp = NULL;
  cfbp = NULL;

  free(fbp);
  fbp = NULL;
}

int main(void)
{
  exerciseFormat(16, 1608);
  exerciseFormat(32, 3204);
  puts("GUI framebuffer pixel/stride tests passed");
  return 0;
}
