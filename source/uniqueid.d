module uniqueid;

import std.bitmanip : nativeToLittleEndian;
import std.array : appender;
import std.string : format;
import config : Config, Gender, toInt;
import draw : Canvas;

string createUid(uint jobid, immutable(Config) config, immutable(Canvas) canvas) pure nothrow @safe
{
    const data = configToByteArray(jobid, config, canvas);

    import std.digest.crc : crc32Of, crcHexString;

    return crcHexString(data.crc32Of);
}

private ubyte[] configToByteArray(uint jobid, immutable(Config) config, immutable(Canvas) canvas) pure nothrow @safe
{
    auto buffer = new ubyte[int.sizeof * 18];

    buffer[0 .. 4] = nativeToLittleEndian(jobid);
    buffer[4 .. 8] = nativeToLittleEndian(config.gender.toInt());
    buffer[8 .. 12] = nativeToLittleEndian(config.head);
    buffer[12 .. 16] = nativeToLittleEndian(config.outfit);
    buffer[16 .. 20] = nativeToLittleEndian(config.garment);
    buffer[20 .. 24] = nativeToLittleEndian(config.weapon);
    buffer[24 .. 28] = nativeToLittleEndian(config.shield);
    buffer[28 .. 32] = nativeToLittleEndian(config.bodyPalette);
    buffer[32 .. 36] = nativeToLittleEndian(config.headPalette);
    buffer[36 .. 40] = nativeToLittleEndian(config.headdir.toInt());
    buffer[40 .. 44] = nativeToLittleEndian(config.enableShadow ? 1 : 0);
    buffer[44 .. 48] = nativeToLittleEndian(canvas.width);
    buffer[48 .. 52] = nativeToLittleEndian(canvas.height);
    buffer[52 .. 56] = nativeToLittleEndian(canvas.originx);
    buffer[56 .. 60] = nativeToLittleEndian(canvas.originy);

    const li = 60; // last index

    import std.algorithm : min;

    const numheadgear = min(3, config.headgear.length);

    long i = 0;
    for (; i < numheadgear; ++i)
    {
        const idx = i * 4;
        buffer[(li + idx) .. (li + idx + 4)] = nativeToLittleEndian(config.headgear[i]);
    }
    i = li + (i * 4 + 4);

    return buffer[0 .. i];
}
