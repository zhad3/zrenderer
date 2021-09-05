module config;

import zconfig : Section, Desc, Short, ConfigFile, Required;

enum Gender
{
    female,
    male
}

string toString(Gender gender) pure nothrow @safe @nogc
{
    switch (gender)
    {
    case Gender.male:
        return "남";
    case Gender.female:
    default:
        return "여";
    }
}

int toInt(Gender gender) pure nothrow @safe @nogc
{
    switch (gender)
    {
    case Gender.male:
        return 1;
    case Gender.female:
    default:
        return 0;
    }
}

enum HeadDirection
{
    straight,
    left,
    right,
    all
}

int toInt(HeadDirection headdir) pure nothrow @safe @nogc
{
    switch (headdir)
    {
    case HeadDirection.straight:
        return 0;
    case HeadDirection.right:
        return 1;
    case HeadDirection.left:
        return 2;
    default:
        return 0;
    }
}

struct Config
{
    @ConfigFile @Short("c") @Desc("Specific config file to use instead of the default.")
    string config = "zrenderer.conf";

    @Short("o") @Desc("Output directory where all rendered sprites will be saved to.")
    string outdir = "output";

    @Desc(
            "Path to the resource directory. All resources are tried to be found within " ~
            "this directory.")
    string resourcepath = "";

    @Short("j") @Desc(
            "Job id(s) which should be rendered. Can contain multiple comma " ~
            "separated values.")
    string[] job;

    @Short("g") @Desc("Gender of the player character. Possible values are: male or female.")
    Gender gender = Gender.male;

    @Desc("Head id which should be used when drawing a player.")
    uint head = 1;

    @Desc("The alternative outfit for player characters. Not all characters have alternative outfits. " ~
            "In these cases the default character will be rendered instead. Value of 0 means no outfit.")
    uint outfit = 0;

    @Desc("Headgears which should be attached to the players head. Can contain up to 3 " ~
            "comma separated values.")
    uint[] headgear;

    @Desc("Garment which should be attached to the players body.")
    uint garment;

    @Desc("Weapon which should be attached to the players body.")
    uint weapon;

    @Desc("Shield which should be attached to the players body.")
    uint shield;

    @Short("a") @Desc("Action of the job which should be drawn.")
    uint action = 0;

    @Short("f") @Desc("Frame of the action which should be drawn. Set to -1 to draw all frames.")
    int frame = -1;

    @Desc("Palette for the body sprite. Set to -1 to use the standard palette.")
    int bodyPalette = -1;

    @Desc("Palette for the head sprite. Set to -1 to use the standard palette.")
    int headPalette = -1;

    @Desc("Direction in which the head should turn. This is only applied to player sprites and only to the stand " ~
            "and sit action. Possible values are: straight, left, right or all. If 'all' is set then this direction " ~
            "system is ignored and all frames are interpreted like any other one.")
    HeadDirection headdir = HeadDirection.all;

    @Desc("Draw shadow underneath the sprite.")
    bool enableShadow = true;

    @Desc("Generate single frames of an animation.")
    bool singleframes = false;

    @Section("server")
    {
        @Desc("Hostnames of the server. Can contain multiple comma separated values.")
        string[] hosts = ["localhost"];

        @Desc("Port of the server.")
        ushort port = 11011;

        @Desc(
                "Log file to write to. E.g. /var/log/zrenderer.log. Leaving it empty will log to stdout.")
        string logfile = "";
    }
}
