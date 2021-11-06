module filehelper;

import config : Config, OutputFormat;
import draw : RawImage;
import logging : LogLevel, LogDg;
import std.zip : ZipArchive;

string[] storeImages(const RawImage[] images, int requestFrame, immutable(Config) config,
        const scope string outputFilename, const scope string zipFilename, LogDg log,
        float animationInterval, ZipArchive archive)
{
    import imageformats.png : saveToPngFile, saveToApngFile;
    import std.file : mkdirRecurse, FileException, read;
    import std.format : format;
    import std.path : buildPath;
    import std.zip : ArchiveMember, CompressionMethod;

    bool shouldPutInZip = config.outputFormat == OutputFormat.zip;
    string[] filenames;

    try
    {
        if (shouldPutInZip)
        {
            mkdirRecurse(buildPath(config.outdir, zipFilename, outputFilename));
        }
        else
        {
            mkdirRecurse(buildPath(config.outdir, outputFilename));
        }
    }
    catch (FileException err)
    {
        log(LogLevel.error, err.msg);
        return [];
    }

    if (config.singleframes)
    {
        foreach (i, image; images)
        {
            auto names = storeImage(image, cast(int) i, outputFilename, config, zipFilename, archive);
            filenames ~= names.filename;
        }
    }

    if (images.length > 1)
    {
        auto names = storeAnimation(images, outputFilename, config, animationInterval, zipFilename, archive);
        filenames ~= names.filename;
    }
    else
    {
        if (requestFrame < 0)
        {
            auto names = storeImage(images[0], -1, outputFilename, config, zipFilename, archive);
            filenames ~= names.filename;
        }
        else
        {
            auto names = storeImage(images[0], requestFrame, outputFilename, config, zipFilename, archive);
            filenames ~= names.filename;
        }
    }

    return filenames;
}

private auto storeImage(const scope RawImage image, int frame, const scope string outputFilename,
        immutable(Config) config, lazy const scope string zipFilename, lazy ZipArchive archive)
{
    import imageformats.png : saveToPngFile;

    auto names = getFilenames(outputFilename, config, zipFilename, config.outputFormat, config.action, frame);

    saveToPngFile(image, names.filename);

    if (config.outputFormat == OutputFormat.zip)
    {
        import std.path : buildPath;

        putFileInZip(archive, names.filename, buildPath(outputFilename, names.basename));
    }

    return names;
}

private auto storeAnimation(const scope RawImage[] images, const scope string outputFilename,
        immutable(Config) config, float animationInterval, lazy const scope string zipFilename,
        lazy ZipArchive archive)
{
    import imageformats.png : saveToApngFile;
    import std.conv : to;

    auto names = getFilenames(outputFilename, config, zipFilename, config.outputFormat, config.action, -1);

    saveToApngFile(images, names.filename, (25 * animationInterval).to!ushort);

    if (config.outputFormat == OutputFormat.zip)
    {
        import std.path : buildPath;

        putFileInZip(archive, names.filename, buildPath(outputFilename, names.basename));
    }

    return names;
}

private auto getFilenames(const scope string outputFilename, immutable(Config) config,
        lazy const scope string zipFilename, OutputFormat outputFormat, int action, int frame)
{
    import std.path : buildPath;
    import std.format : format;

    struct Filenames
    {
        string basename;
        string filename;
    }

    Filenames names;

    names.basename = (frame < 0) ? format("%d.png", action) : format("%d-%d.png", action, frame);
    names.filename = (outputFormat == OutputFormat.zip)
        ? buildPath(config.outdir, zipFilename, outputFilename, names.basename)
        : buildPath(config.outdir, outputFilename, names.basename);

    return names;
}

private void putFileInZip(ZipArchive archive, const scope string filename, const scope string nameInZip)
{
    import std.file : read;
    import std.zip : ArchiveMember, CompressionMethod;

    auto member = new ArchiveMember();
    member.compressionMethod = CompressionMethod.none;
    member.name = nameInZip;
    member.expandedData(cast(ubyte[]) read(filename));
    archive.addMember(member);
}

