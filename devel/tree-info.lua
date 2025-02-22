--Print a tree_info visualization of the tree at the cursor.
--@module = true

-- [w][n][e][s]
local branch_chars = {
    [true]={
        [true]={
            [true]={
                [true]=string.char(197), --WNES
                [false]=string.char(193), --WNE
            },
            [false]={
                [true]=string.char(180), --WNS
                [false]=string.char(217), --WN
            },
        },
        [false]={
            [true]={
                [true]=string.char(194), --WES
                [false]=string.char(196), --WE
            },
            [false]={
                [true]=string.char(191), --WS
                [false]=string.char(26), --W
            },
        },
    },
    [false]={
        [true]={
            [true]={
                [true]=string.char(195), --NES
                [false]=string.char(192), --NE
            },
            [false]={
                [true]=string.char(179), --NS
                [false]=string.char(25), --N
            },
        },
        [false]={
            [true]={
                [true]=string.char(218), --ES
                [false]=string.char(27), --E
            },
            [false]={
                [true]=string.char(24), --S
                [false]=' ',
            },
        },
    },
}

local function print_color(s, color)
    dfhack.color(color)
    dfhack.print(dfhack.df2console(s))
    dfhack.color(COLOR_RESET)
end

function printTreeTile(bits)
    local chars = 8 --launcher doesn't like tab
    local exists

    if bits.trunk then
        chars = chars-1
        exists = true

        if bits.trunk_is_thick then
            print_color('@', COLOR_BROWN)
        else
            print_color('O', COLOR_BROWN)
        end
    end

    if bits.branches then
        chars = chars-1
        exists = true
        print_color(string.char(172), COLOR_GREEN) --1/4
    end

    if bits.trunk ~= bits.branches then --align properly
        chars = chars-1
        dfhack.print(' ')
    end

    if bits.leaves then
        chars = chars-1
        exists = true
        print_color(';', COLOR_GREEN)
    end

    if bits.blocked then
        chars = chars-1
        print_color('x', COLOR_RED)
    elseif not exists then
        chars = chars-1
        dfhack.print('.')
    end

    chars = chars-2
    print_color(' '..(branch_chars[bits.branch_w][bits.branch_n][bits.branch_e][bits.branch_s] or '?'), COLOR_GREY)

    local dir = bits.parent_dir
    if dir > 0 then
        chars = chars-2
        if dir == 1 then
            print_color(' N', COLOR_DARKGREY)
        elseif dir == 2 then
            print_color(' S', COLOR_DARKGREY)
        elseif dir == 3 then
            print_color(' W', COLOR_DARKGREY)
        elseif dir == 4 then
            print_color(' E', COLOR_DARKGREY)
        elseif dir == 5 then
            print_color(' U', COLOR_DARKGREY)
        elseif dir == 6 then
            print_color(' D', COLOR_DARKGREY)
        else
            print_color(' ?', COLOR_DARKGREY)
        end
    end

    dfhack.print((' '):rep(chars))
end

function printRootTile(bits)
    local chars = 8 --launcher doesn't like tab
    local exists

    if bits.regular then
        chars = chars-1
        exists = true
        print_color(string.char(172), COLOR_BROWN) --1/4
    end

    if bits.blocked then
        chars = chars-1
        print_color('x', COLOR_RED)
    elseif not exists then
        chars = chars-1
        dfhack.print('.')
    end

    dfhack.print((' '):rep(chars))
end

function printTree(t)
    local div = ('-'):rep(t.dim_x*8+1)
    print(div)

    for z = t.body_height-1, 0, -1 do
        for i = 0, t.dim_x*t.dim_y-1 do
            printTreeTile(t.body[z]:_displace(i))

            if i%t.dim_x == t.dim_x-1 then
                print('|') --next line
            end
        end

        print(div)
    end

    for z = 0, t.roots_depth-1 do
        for i = 0, t.dim_x*t.dim_y-1 do
            printRootTile(t.roots[z]:_displace(i))

            if i%t.dim_x == t.dim_x-1 then
                print('|') --next line
            end
        end

        print(div)
    end
end

if not dfhack_flags.module then
    local p = dfhack.maps.getPlantAtTile(copyall(df.global.cursor))
    if p and p.tree_info then
        printTree(p.tree_info)
    else
        qerror('No tree!')
    end
end
