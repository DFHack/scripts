# Profile JSON format
I highly suggest to use a tool like "JSONLint" to validate your JSON.
Simply go to this website: https://jsonlint.com/, paste your JSON and
click "Validate JSON".
  
## Profile name
Each profile is a JSON object with a unique name.
```json
{
  "MY_PROFILE": {}
}
```
## Comment section
It is possible to add a comment to the profile.
```json
{
  "MY_PROFILE": {
    "comment": "This is a comment."
  }
}
```
## ATTRIBUTES section
The ATTRIBUTES section in a JSON object.
```json
{
  "MY_PROFILE": {
    "ATTRIBUTES": {
      "STRENGTH": 1,
      "AGILITY": 1,
      "CREATIVITY": 2
    } 
  }
}
```
## SKILLS section
The SKILLS section is similiar to the ATTRIBUTES section.
```json
{
  "MY_PROFILE": {
    "SKILLS": {
      "CARPENTRY": 3,
      "WOODCRAFT": 1
    }
  }
}
```
## PREFERENCES section
Each preference type is an array of tokens. Refer to the documentation of the
 `assign-preferences` script for information about each type.
```json
{
  "MY_PROFILE": {
    "PREFERENCES" : {
      "LIKEMATERIAL" : [
        "INORGANIC:OBSIDIAN",
        "INORGANIC:COPPER",
        "INORGANIC:AMETHYST",
        "PLANT:WILLOW:WOOD",          
        "CREATURE:WILD_BOAR:IVORY"        
      ],
      "LIKEITEM" : [
        "ITEM_WEAPON:ITEM_WEAPON_AXE_BATTLE",        
        "ITEM_TOOL:ITEM_TOOL_KNIFE_CARVING",
        "WOOD"
      ],
      "LIKEFOOD" : [
        "CREATURE:HORSE:MUSCLE",
        "CREATURE:SHEEP:CHEESE",
        "PLANT:BERRIES_STRAW:FRUIT",
        "CREATURE:COW:MILK",
        "PLANT:POD_SWEET:EXTRACT",
        "CREATURE:HONEY_BEE:MEAD"
      ],
      "LIKECREATURE": [
        "DOG"
      ],
      "LIKEPLANT": [
        "BLUEBERRY"
      ],
      "LIKETREE": [
        "OAK"
      ],
      "LIKECOLOR": [
        "AQUA"
      ],
      "LIKESHAPE": [
        "STAR"
      ]
    }
  }
}
```
## BELIEFS section
The BELIEFS section is similar to the ATTRIBUTES section.
```json
{
  "MYPROFILE": {
    "BELIEFS" : {
      "LOYALTY" : 1,
      "FAMILY" : 1,
      "FRIENDSHIP" : 2,
      "COMPETITION": -2
    }
  }
}
```
## GOALS section
The GOALS section is a JSON object. Its keys are the goal tokens, its values are boolean.
```json
{
  "MYPROFILE": {
    "GOALS" : {
      "BRING_PEACE_TO_THE_WORLD": false
    }
  }
}
```
## FACETS section
The FACETS section is similar to the ATTRIBUTES section.
```json
{
  "MYPROFILE": {
    "FACETS": {
      "HATE_PROPENSITY": -1,
      "ANGER_PROPENSITY": -1,
      "STRESS_VULNERABILITY": 1,
      "DISCORD": -2,
      "FRIENDLINESS": 2
    }
  }
}
```
