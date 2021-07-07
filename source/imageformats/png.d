module imageformats.png;

import std.stdio : File;
import draw : RawImage;
import libpng.png;

void saveToPngFile(const scope RawImage image, string filename)
{

    auto file = File(filename, "wb");

    png_bytep[] png_row_pointers = new png_bytep[image.height];

    for (auto rowIndex = 0; rowIndex < image.height; ++rowIndex)
    {
        png_row_pointers[rowIndex] = cast(png_bytep) &image.pixels[rowIndex * image.width];
    }

    png_structp png_ptr = png_create_write_struct(PNG_LIBPNG_VER_STRING, null, null, null);
    png_infop png_info_ptr = png_create_info_struct(png_ptr);
    scope(failure)
    {
        png_destroy_write_struct(&png_ptr, &png_info_ptr);
    }

    png_set_IHDR(png_ptr,
            png_info_ptr,
            image.width,
            image.height,
            8,
            PNG_COLOR_TYPE_RGB_ALPHA,
            PNG_INTERLACE_NONE,
            PNG_COMPRESSION_TYPE_BASE,
            PNG_FILTER_TYPE_BASE);

    png_init_io(png_ptr, file.getFP());
    png_set_rows(png_ptr, png_info_ptr, cast(ubyte**) png_row_pointers);
    png_write_png(png_ptr, png_info_ptr, PNG_TRANSFORM_IDENTITY, null);

    png_destroy_write_struct(&png_ptr, &png_info_ptr);
}

void saveToApngFile(const scope RawImage[] images, string filename, ushort delay)
{
    auto file = File(filename, "wb");

    png_bytep[] png_row_pointers = new png_bytep[images[0].height];

    png_structp png_ptr = png_create_write_struct(PNG_LIBPNG_VER_STRING, null, null, null);
    png_infop png_info_ptr = png_create_info_struct(png_ptr);
    scope(failure)
    {
        png_destroy_write_struct(&png_ptr, &png_info_ptr);
    }

    png_set_IHDR(png_ptr,
            png_info_ptr,
            images[0].width,
            images[0].height,
            8,
            PNG_COLOR_TYPE_RGB_ALPHA,
            PNG_INTERLACE_NONE,
            PNG_COMPRESSION_TYPE_BASE,
            PNG_FILTER_TYPE_BASE);

    png_set_acTL(png_ptr, png_info_ptr, cast(uint) images.length, 0);

    png_init_io(png_ptr, file.getFP());

    png_write_info(png_ptr, png_info_ptr);

    foreach (image; images) {
        for (auto rowIndex = 0; rowIndex < image.height; ++rowIndex)
        {
            png_row_pointers[rowIndex] = cast(png_bytep) &image.pixels[rowIndex * image.width];
        }

        png_write_frame_head(png_ptr, png_info_ptr, null, image.width, image.height, 0, 0, delay, 100,
                PNG_DISPOSE_OP_NONE, PNG_BLEND_OP_SOURCE);
        png_write_image(png_ptr, cast(ubyte**) png_row_pointers);
        png_write_frame_tail(png_ptr, png_info_ptr);
    }

    png_write_end(png_ptr, png_info_ptr);
    //png_set_rows(png_ptr, png_info_ptr, cast(ubyte**) png_row_pointers);
    //png_write_png(png_ptr, png_info_ptr, PNG_TRANSFORM_IDENTITY, null);

    png_destroy_write_struct(&png_ptr, &png_info_ptr);
}
