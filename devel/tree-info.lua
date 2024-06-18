--Print a tree_info visualization of the tree at the cursor.
--@module = true

local branch_dir =
{
    [0] = ' ',
    [1] = string.char(26), --W
    [2] = string.char(25), --N
    [3] = string.char(217), --WN
    [4] = string.char(27), --E
    [5] = string.char(196), --WE
    [6] = string.char(192), --NE
    [7] = string.char(193), --WNE
    [8] = string.char(24), --S
    [9] = string.char(191), --WS
    [10] = string.char(179), --NS
    [11] = string.char(180), --WNS
    [12] = string.char(218), --ES
    [13] = string.char(194), --WES
    [14] = string.char(195), --NES
    [15] = string.char(197), --WNES
}

local function print_color(s, color)
    dfhack.color(color)
    dfhack.print(s)
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
    print_color(' '..(branch_dir[bits.branches_dir] or '?'), COLOR_GREY)

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
