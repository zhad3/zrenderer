# Resources required to run zrenderer

The renderer just as the official client requires a certain amount of files to run which are included in the GRF files.

The files need to be **unencrypted** and **uncompressed**. It was decided to not directly reference the GRF because it is easier to implement. It also reduces the load on memory usage (but increases disk usage).

You can use https://github.com/zhad3/zextractor to extract the required files. It allows setting filters which extract only the required files.

The following files are used by the renderer. Please note that the lua files are **mandatory**. Obviously so are the sprite files. In case where you do not want to render e.g. NPCs or monsters you could omit these.

```
data\sprite\인간족\
data\sprite\도람족\
data\sprite\방패\
data\sprite\로브\
data\sprite\악세사리\
data\sprite\몬스터\
data\sprite\homun\
data\sprite\npc\
data\palette\
data\imf\
data\luafiles514\lua files\datainfo\accessoryid.
data\luafiles514\lua files\datainfo\accname.
data\luafiles514\lua files\datainfo\accname_f.
data\luafiles514\lua files\datainfo\spriterobeid.
data\luafiles514\lua files\datainfo\spriterobename.
data\luafiles514\lua files\datainfo\spriterobename_f.
data\luafiles514\lua files\datainfo\weapontable.
data\luafiles514\lua files\datainfo\weapontable_f.
data\luafiles514\lua files\datainfo\jobidentity.
data\luafiles514\lua files\datainfo\npcidentity.
data\luafiles514\lua files\datainfo\jobname.
data\luafiles514\lua files\datainfo\jobname_f.
data\luafiles514\lua files\datainfo\shadowtable.
data\luafiles514\lua files\datainfo\shadowtable_f.
data\luafiles514\lua files\skillinfoz\jobinheritlist.
data\luafiles514\lua files\spreditinfo\2dlayerdir_f.
data\luafiles514\lua files\spreditinfo\biglayerdir_female.
data\luafiles514\lua files\spreditinfo\biglayerdir_male.
data\luafiles514\lua files\spreditinfo\_new_2dlayerdir_f.
data\luafiles514\lua files\spreditinfo\_new_biglayerdir_female.
data\luafiles514\lua files\spreditinfo\_new_biglayerdir_male.
data\luafiles514\lua files\spreditinfo\_new_smalllayerdir_female.
data\luafiles514\lua files\spreditinfo\_new_smalllayerdir_male.
data\luafiles514\lua files\spreditinfo\smalllayerdir_female.
data\luafiles514\lua files\spreditinfo\smalllayerdir_male.
data\luafiles514\lua files\offsetitempos\offsetitempos_f.
data\luafiles514\lua files\offsetitempos\offsetitempos.
data\sprite\shadow.
```
The format is ready to be used for the aforementioned zextractor.

