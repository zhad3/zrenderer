# Resolver
## About this document
Details about how the resolver is looking up the resources to draw the sprite from the input variables.

Almost everything written here is taken directly from the source code [resolver.d](https://github.com/zhad3/zrenderer/blob/main/source/resolver.d).

## Sprite types
As of this writing there are the following sprite types that can be composed to a fully rendered image:

- Job (or "Body", this includes Monsters, NPCs, Homunculus and Mercenaries)
- Head
- Headgear
- Garment
- Weapon
- Weapon Slash
- Shield
- Shadow
- ~~Cart~~ (Currently not supported)
- ~~Companion (e.g. Falcon)~~ (Currently not supported)

## Input to Sprite type mapping and resource resolving

Preface: Gender is used in a lot of places and is interpreted as following:  
| Gender (-\-gender) | Name |
| --- | --- |
| 0 | 여 |
| 1 | 남 |

<table>
  <thead>
    <tr>
      <th>Sprite type</th>
      <th>Inputs</th>
      <th>Resource</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td rowspan="2">Job</td>
      <td rowspan="2">--job<br>--gender<br>--outfit</td>
      <td>
        <b>Player</b><br>
        <code>jobname</code>=<a href="https://github.com/zhad3/zrenderer/blob/main/resolver_data/job_names.txt">job_names.txt</a> (Line #&lt;job&gt;, if the job id is greater than 4000 then 3950 is subtracted)<br><br>
        Player: <code>data/sprite/인간족/몸통/&lt;gender&gt;/&lt;job&gt;_&lt;gender&gt;.{spr,act}</code><br>
        Player (doram): <code>data/sprite/도람족/몸통/&lt;gender&gt;/&lt;jobname&gt;_&lt;gender&gt;.{spr,act}</code><br>
        Player (outfit): <code>data/sprite/인간족/몸통/&lt;gender&gt;/costume_&lt;outfit&gt;/&lt;jobname&gt;_&lt;gender&gt;_&lt;outfit&gt;.{spr,act}</code><br>
        Player (doram,outfit): <code>data/sprite/도람족/몸통/&lt;gender&gt;/costume_&lt;outfit&gt;/&lt;jobname&gt;_&lt;gender&gt;_&lt;outfit&gt;.{spr,act}</code>
      </td>
    </tr>
    <tr>
      <td>
        <b>Non player</b><br>
        <code>jobname</code>=<code>data/luafiles514/lua files/datainfo/jobname_f.lub#ReqJobName(&lt;job&gt;)</code> (function takes value from <code>jobname.lub</code>.<br><br>
        Monster: <code>data/sprite/몬스터/&lt;jobname&gt;.{spr,act}</code><br>
        NPC: <code>data/sprite/npc/&lt;jobname&gt;.{spr,act}</code><br>
        Mercenary: <code>data/sprite/인간족/몸통/&lt;jobname&gt;.{spr,act}</code><br>
        Homunculus: <code>data/sprite/homun/&lt;jobname&gt;.{spr,act}</code><br><br>
        <i>Hint: For the differentiation between the nonplayer job ids have a look at <a href="https://github.com/zhad3/zrenderer/blob/main/source/resolver.d">resolver.d</a>.</i>
      </td>
    </tr>
    <tr>
      <td>Head</td>
      <td>--job<br>--head<br>--gender</td>
      <td>
        Human: <code>data/sprite/인간족/머리통/&lt;gender&gt;/&lt;head&gt;_&lt;gender&gt;.{spr,act}</code><br>
        Doram: <code>data/sprite/도람족/머리통/&lt;gender&gt;/&lt;head&gt;_&lt;gender&gt;.{spr,act}</code>
      </td>
    </tr>
    <tr>
      <td>Headgear</td>
      <td>--headgear<br>--gender</td>
      <td>
        <code>name</code>=<code>data/luafiles514/lua files/datainfo/accname_f.lub#ReqAccName(&lt;headgear&gt;)</code> (function takes value from <code>accname.lub</code>.<br><br>
        Headgear: <code>data/sprite/악세사리/&lt;gender&gt;/&lt;gender&gt;&lt;name&gt;.{spr,act}</code><br><br>
        <i>Hint: For a list of human readable ids take a look at the lua file <code>accessoryid.lua</code></i>
      </td>
    </tr>
    <tr>
      <td>Garment</td>
      <td>--job<br>--gender<br>--garment</td>
      <td>
        <code>name</code>=<code>data/luafiles514/lua files/datainfo/spriterobename_f.lub#ReqRobSprName_V2(&lt;garment&gt;)</code> (function takes value from <code>spriterobename.lub</code>.<br>
        <code>jobname</code>=<a href="https://github.com/zhad3/zrenderer/blob/main/resolver_data/job_names.txt">job_names.txt</a> (Line #&lt;job&gt;, if the job id is greater than 4000 then 3950 is subtracted)<br><br>
        Garment: <code>data/sprite/로브/&lt;name&gt;/&lt;gender&gt;/&lt;jobname&gt;_&lt;gender&gt;.{spr,act}</code><br>
        Garment (fallback): <code>data/sprite/로브/&lt;name&gt;/&lt;name&gt;.{spr,act}</code><br><br>
        <i>Hint: For a list of human readable ids take a look at the lua file <code>spriterobeid.lua</code></i>
      </td>
    </tr>
    <tr>
      <td rowspan="2">Weapon</td>
      <td rowspan="2">--job<br>--gender<br>--weapon</td>
      <td>
        <b>Player</b><br>
        <code>name</code>=<code>data/luafiles514/lua files/datainfo/weapontable_f.lub#ReqWeaponName(&lt;weapon&gt;)</code> (function takes value from <code>weapontable.lub</code>.<br>
        If no name is found then try again with a new weapon id:
        <code>weapon</code>=<code>data/luafiles514/lua files/datainfo/weapontable_f.lub#GetRealWeaponId(&lt;weapon&gt;)</code><br>
        If there is still no name then just use the weapon id itself as name:
        <code>name</code>=<code>_&lt;weapon&gt;</code><br>
        <code>jobname</code>=<a href="https://github.com/zhad3/zrenderer/blob/main/resolver_data/job_weapon_names.txt">job_weapon_names.txt</a> (Line #&lt;job&gt;, if the job id is greater than 4000 then 3950 is subtracted)<br><br>
        Human: <code>data/sprite/인간족/&lt;jobname&gt;_&lt;gender&gt;&lt;name&gt;.{spr,act}</code><br>
        Doram: <code>data/sprite/도람족/&lt;jobname&gt;_&lt;gender&gt;&lt;name&gt;.{spr,act}</code><br><br>
        <i>Hint: For a list of human readable ids take a look at the lua file <code>weapontable.lua</code></i>
      </td>
    </tr>
    <tr>
      <td>
        <b>Mercenary</b><br>
        Archer: <code>data/sprite/인간족/용병/활용병_활.{spr,act}</code><br>
        Lancer: <code>data/sprite/인간족/용병/창용병_창.{spr,act}</code><br>
        Swordsman: <code>data/sprite/인간족/용병/검용병_검.{spr,act}</code>
      </td>
    </tr>
    <tr>
      <td>Weapon Slash</td>
      <td colspan="2">Same as Weapon but with a <code>_검광</code> suffix.</td>
    </tr>
    <tr>
      <td>Shield</td>
      <td>--job<br>--gender<br>--shield</td>
      <td>
          <code>name</code>=<a href="https://github.com/zhad3/zrenderer/blob/main/resolver_data/shield_names.txt">shield_names.txt</a> (Line #&lt;shield&gt;)<br>
          <code>name</code>(fallback)=<code>_&lt;shield&gt;_방패</code><br>
        <code>jobname</code>=<a href="https://github.com/zhad3/zrenderer/blob/main/resolver_data/job_names.txt">job_names.txt</a> (Line #&lt;job&gt;, if the job id is greater than 4000 then 3950 is subtracted)<br><br>
        Shield: <code>data/sprite/방패/&lt;jobname&gt;/&lt;jobname&gt;_&lt;gender&gt;&lt;name&gt;.{spr,act}</code>
      </td>
    </tr>
    <tr>
      <td>Shadow</td>
      <td>--enableShadow</td>
      <td>Shadow: <code>data/sprite/shadow.{spr,act}</code></td>
    </tr>
  </tbody>
</table>

## Palettes
Body (+outfits) and head sprites can be colored via palettes. These are resolved as following.

<table>
  <thead>
    <th>Palette type</th>
    <th>Inputs</th>
    <th>Resource</th>
  </thead>
  <tbody>
    <tr>
      <td>Job</td>
      <td>--job<br>--gender<br>--bodyPalette<br>--outfit</td>
      <td>
        <code>jobname</code>=<a href="https://github.com/zhad3/zrenderer/blob/main/resolver_data/job_pal_names.txt">job_pal_names.txt</a> (Line #&lt;bodyPalette&gt;)<br><br>
        Human: <code>data/palette/몸/&lt;jobname&gt;_&lt;gender&gt;_&lt;bodyPalette&gt;.pal</code><br>
        Doram: <code>data/palette/도람족/body/&lt;jobname&gt;_&lt;gender&gt;_&lt;bodyPalette&gt;.pal</code><br>
        Human (outfit): <code>data/palette/몸/costume_&lt;outfit&gt;/&lt;jobname&gt;_&lt;gender&gt;_&lt;bodyPalette&gt;_&lt;outfit&gt;.pal</code><br>
        Doram (outfit): <code>data/palette/도람족/body/costume_&lt;outfit&gt;/&lt;jobname&gt;_&lt;gender&gt;_&lt;bodyPalette&gt;_&lt;outfit&gt;.pal</code>
      </td>
    </tr>
    <tr>
      <td>Head</td>
      <td>--job<br>--gender<br>--head<br>--headPalette</td>
      <td>
        Human: <code>data/palette/머리/머리&lt;head&gt;_&lt;gender&gt;_&lt;headPalette&gt;.pal</code><br>
        Doram: <code>data/palette/도람족/머리/머리&lt;head&gt;_&lt;gender&gt;_&lt;headPalette&gt;.pal</code><br>
      </td>
    </tr>
  </tbody>
</table>

