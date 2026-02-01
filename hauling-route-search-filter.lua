-- Search/filter hauling routes from the Hauling menu.
--[====[

gui/hauling-search
==================
Activate in the :guilabel:`Hauling` menu (press :kbd:`h`) to
filter the native hauling route list by name or id. The filter
hides non-matching routes in the in-game list and restores the
full list when cleared.

]====]
--@ module = true

local overlay = require 'plugins.overlay'
local widgets = require 'gui.widgets'

local last_filter = ''
local STOP_KEY = {}

local function safe_field(obj, field)
    local ok, value = pcall(function() return obj[field] end)
    if ok then
        return value
    end
    return nil
end

local function resolve_route(hauling, route_ref)
    if not hauling or not route_ref then return nil end
    local name = safe_field(route_ref, 'name')
    local id = safe_field(route_ref, 'id')
    if name ~= nil or id ~= nil then
        return route_ref
    end
    local route_id = safe_field(route_ref, 'route_id')
    if route_id ~= nil then
        local routes = safe_field(hauling, 'routes')
        if routes then return routes[route_id] end
    end
    return nil
end

local function resolve_route_id(hauling, route_ref, stop_ref)
    local route = resolve_route(hauling, route_ref)
    if route and route.id ~= nil then
        return route.id
    end
    local stop_route_id = safe_field(stop_ref, 'route_id')
    if stop_route_id ~= nil then
        return stop_route_id
    end
    return nil
end

local function get_route_name(route)
    if not route then return 'Route ?' end
    return route.name and #route.name > 0 and route.name or ('Route '..route.id)
end

local function is_match(filter, route)
    if not route then return false end
    if filter == '' then return true end
    local needle = filter:lower()
    local name = get_route_name(route):lower()
    if name:find(needle, 1, true) then return true end
    if tostring(route.id):find(needle, 1, true) then return true end
    return false
end

local function build_matching_route_ids(hauling, filter)
    local matching_route_ids = {}
    local routes = safe_field(hauling, 'routes')
    if not routes then return matching_route_ids end
    for i = 0, #routes - 1 do
        local route = routes[i]
        if is_match(filter, route) then
            if route and route.id ~= nil then
                matching_route_ids[route.id] = true
            end
        end
    end
    return matching_route_ids
end

local function snapshot_rows(hauling)
    local view_routes = safe_field(hauling, 'view_routes')
    local view_stops = safe_field(hauling, 'view_stops')
    if not view_routes or not view_stops then return nil end
    local rows = {}
    for i = 0, #view_routes - 1 do
        local route_ref = view_routes[i]
        local stop_ref = view_stops[i]
        local route_id = resolve_route_id(hauling, route_ref, stop_ref)
        local stop_id = safe_field(stop_ref, 'id')
        table.insert(rows, {
            route=route_ref,
            stop=stop_ref,
            route_id=route_id,
            stop_id=stop_id,
        })
    end
    return rows
end

local function snapshot_routes(hauling)
    local routes = safe_field(hauling, 'routes')
    if not routes then return nil end
    local rows = {}
    for i = 0, #routes - 1 do
        local route = routes[i]
        if route then
            table.insert(rows, {
                route=route,
                stop=nil,
                route_id=route.id,
                stop_id=nil,
            })
            local stops = safe_field(route, 'stops')
            if stops then
                for j = 0, #stops - 1 do
                    local stop = stops[j]
                    table.insert(rows, {
                        route=route,
                        stop=stop,
                        route_id=route.id,
                        stop_id=safe_field(stop, 'id'),
                    })
                end
            end
        end
    end
    return rows
end

local function get_route_signature(hauling)
    local routes = safe_field(hauling, 'routes')
    if not routes then return nil end
    local parts = {}
    for i = 0, #routes - 1 do
        local route = routes[i]
        local id = route and route.id or 'nil'
        local stops = route and safe_field(route, 'stops')
        local stop_count = stops and #stops or 0
        table.insert(parts, tostring(id) .. ':' .. tostring(stop_count))
    end
    return table.concat(parts, '|')
end

local function rebuild_rows(hauling, rows)
    local view_routes = safe_field(hauling, 'view_routes')
    local view_stops = safe_field(hauling, 'view_stops')
    if not view_routes or not view_stops then return end
    view_routes:resize(0)
    view_stops:resize(0)
    for _, row in ipairs(rows) do
        view_routes:insert('#', row.route)
        view_stops:insert('#', row.stop)
    end
end

local function merge_rows(existing_rows, hauling)
    local view_routes = safe_field(hauling, 'view_routes')
    local view_stops = safe_field(hauling, 'view_stops')
    if not view_routes or not view_stops then return existing_rows end
    local seen = {}
    for idx, row in ipairs(existing_rows) do
        local route_key = row.route_id or row.route or idx
        local stop_key = row.stop_id or row.stop or STOP_KEY
        seen[tostring(route_key) .. ':' .. tostring(stop_key)] = true
    end
    for i = 0, #view_routes - 1 do
        local route_ref = view_routes[i]
        local stop_ref = view_stops[i]
        local route_id = resolve_route_id(hauling, route_ref, stop_ref)
        local stop_id = safe_field(stop_ref, 'id')
        local route_key = route_id or route_ref or i
        local stop_key = stop_id or stop_ref or STOP_KEY
        local key = tostring(route_key) .. ':' .. tostring(stop_key)
        if not seen[key] then
            table.insert(existing_rows, {
                route=route_ref,
                stop=stop_ref,
                route_id=route_id,
                stop_id=stop_id,
            })
            seen[key] = true
        end
    end
    return existing_rows
end

HaulingRouteFilterOverlay = defclass(HaulingRouteFilterOverlay, overlay.OverlayWidget)
HaulingRouteFilterOverlay.ATTRS{
    desc='Adds an inline filter box to the hauling routes list.',
    default_enabled=true,
    default_pos={x=8, y=6},
    frame={w=46, h=1},
    viewscreens='dwarfmode/Hauling',
}

function HaulingRouteFilterOverlay:init()
    self.hauling = df.global.plotinfo.hauling
    self:addviews{
        widgets.Panel{
            subviews={
                widgets.EditField{
                    view_id='filter',
                    frame={t=0, l=1, r=1},
                    key='CUSTOM_ALT_S',
                    label_text='Filter: ',
                    text=last_filter,
                    on_change=self:callback('on_filter_change'),
                },
            },
        },
    }
end

function HaulingRouteFilterOverlay:overlay_onupdate()
    if self.filter_text then
        self:apply_filter(self.filter_text)
    end
end

function HaulingRouteFilterOverlay:snapshot_rows()
    return snapshot_rows(self.hauling)
end

function HaulingRouteFilterOverlay:restore_rows()
    if not self.unfiltered_rows then return end
    local refreshed = snapshot_routes(self.hauling)
    if refreshed then
        self.unfiltered_rows = refreshed
    end
    self.unfiltered_rows = merge_rows(self.unfiltered_rows, self.hauling)
    rebuild_rows(self.hauling, self.unfiltered_rows)
    self.unfiltered_rows = nil
    self.route_signature = nil
end

function HaulingRouteFilterOverlay:apply_filter(filter)
    if filter == '' then
        self:restore_rows()
        return
    end
    if not self.unfiltered_rows then
        self.unfiltered_rows = self:snapshot_rows() or snapshot_routes(self.hauling)
        self.route_signature = get_route_signature(self.hauling)
    else
        local signature = get_route_signature(self.hauling)
        if signature and signature ~= self.route_signature then
            local refreshed = snapshot_routes(self.hauling)
            if refreshed then
                self.unfiltered_rows = refreshed
                self.route_signature = signature
            end
        end
    end
    if not self.unfiltered_rows then return end
    local matching_route_ids = build_matching_route_ids(self.hauling, filter)
    local filtered = {}
    for _, row in ipairs(self.unfiltered_rows) do
        local route_id = row.route_id or resolve_route_id(self.hauling, row.route, row.stop)
        local resolved_route = resolve_route(self.hauling, row.route)
        local is_match_id = route_id ~= nil and matching_route_ids[route_id]
        local is_match_route = is_match(filter, resolved_route)
        if is_match_id or is_match_route then
            table.insert(filtered, row)
        end
    end
    rebuild_rows(self.hauling, filtered)
end

function HaulingRouteFilterOverlay:on_filter_change(text)
    self.filter_text = text
    last_filter = text
    self:apply_filter(text)
end

function HaulingRouteFilterOverlay:overlay_onenable()
    if not self then return end
    local filter = self.subviews.filter
    if filter then
        filter:setFocus(false)
    end
end

function HaulingRouteFilterOverlay:onInput(keys)
    if keys.SELECT then return false end
    return HaulingRouteFilterOverlay.super.onInput(self, keys)
end

function HaulingRouteFilterOverlay:overlay_ondisable()
    self:restore_rows()
end

OVERLAY_WIDGETS = {filter=HaulingRouteFilterOverlay}

if dfhack_flags.module then
    return
end

if not dfhack.gui.matchFocusString('dwarfmode/Hauling') then
    qerror('This script must be run from the Hauling screen.')
end

overlay.overlay_command({'enable', 'hauling-search.filter'})
