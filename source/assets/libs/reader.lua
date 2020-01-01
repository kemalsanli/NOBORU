local Pages = {}
local  velX, velY = 0, 0

local TOUCH_IDLE        = 0
local TOUCH_MULTI       = 1
local TOUCH_MOVE        = 2
local TOUCH_READ        = 3
local TOUCH_SWIPE       = 4
local touchMode         = TOUCH_IDLE

local PAGE_NONE         = 0
local PAGE_LEFT         = 1
local PAGE_RIGHT        = 2
local pageMode          = PAGE_NONE

local max_zoom = 2

local offset = { x = 0, y = 0 }
local touchTemp = { x = 0, y = 0 }

local Scale = function (dzoom, Page)
    local old_zoom = Page.zoom
    Page.zoom = Page.zoom * dzoom
    if Page.zoom < Page.min_zoom then
        Page.zoom = Page.min_zoom
    elseif Page.zoom > max_zoom then
        Page.zoom = max_zoom
    end
    Page.y = 272 + ((Page.y - 272) / old_zoom) * Page.zoom
    Page.x = 480 + ((Page.x - 480) / old_zoom) * Page.zoom
end

local ChangePage = function (page)
    if page <= 0 or page > #Pages then
        return false
    end
    Pages.page = page
    for i = -1, 1 do
        if page + i > 0 and page + i <= #Pages then
            if Pages[page + i].image == nil then
                Net.downloadImageAsync(Pages[page + i].link, Pages[page + i], 'image')
            end
        end
    end
    if page - 3 > 0 then
        Net.remove (Pages[page - 3], 'image')
        if Pages[page - 3].image ~= nil then
            Graphics.freeImage (Pages[page - 3].image)
        end
        Pages[page - 3] = { link = Pages[page - 3].link, x = 0, y = 0 }
    end
    if page + 3 < #Pages then
        Net.remove (Pages[page + 3], 'image')
        if Pages[page + 3].image ~= nil then
            Graphics.freeImage (Pages[page + 3].image)
        end
        Pages[page + 3] = { link = Pages[page + 3].link, x = 0, y = 0 }
    end
    return true
end

Reader = {
    draw = function ()
        for i = -1, 1 do
            local page = Pages[Pages.page + i]
            if page~= nil and page.image ~= nil then
                Graphics.drawImageExtended(offset.x + page.x, offset.y + page.y, page.image, 0, 0, page.width, page.height, 0, page.zoom, page.zoom)
            elseif page~= nil then
                Graphics.debugPrint (offset.x + 0, 524, "Loading "..string.sub("...",1,(Timer.getTime(GlobalTimer)/400)%3+1), LUA_COLOR_PURPLE)
            end
        end
    end,
    update = function ()
        if Pages[Pages.page] == nil then
            return
        end
        for i = -1, 1 do
            local page = Pages[Pages.page + i]
            if page ~= nil and page.zoom == nil and page.image ~= nil then
                local image = page.image
                page.width, page.height, page.x, page.y = Graphics.getImageWidth(image), Graphics.getImageHeight(image), 480+i*960, 272
                Console.addLine("Added "..Pages.page + i)
                if page.width > page.height then
                    page.mode = "Horizontal"
                    page.zoom = 544 / page.height
                    page.min_zoom = page.zoom
                    if page.width*page.zoom >= 960 then
                        page.x = 480+i*(480+page.width*page.zoom/2)
                    else
                        page.x = 480+i*960
                    end
                else
                    page.mode = "Vertical"
                    page.zoom = 960 / page.width
                    page.min_zoom = page.zoom
                    page.x = 480+i*960
                end
                page.y = page.zoom*page.height/2
            end
        end
        if touchMode == TOUCH_READ then
            local len = math.sqrt((touchTemp.x-Touch.x)*(touchTemp.x-Touch.x) + (touchTemp.y-Touch.y)*(touchTemp.y-Touch.y))
            if  len > 10 then
                if math.abs(Touch.x - touchTemp.x) > math.abs(Touch.y - touchTemp.y)*3  and ((bit32.band(pageMode,PAGE_RIGHT)~=0 and touchTemp.x > Touch.x) or (bit32.band(pageMode,PAGE_LEFT)~=0 and touchTemp.x < Touch.x)) then
                    touchMode = TOUCH_SWIPE
                    velY = 0
                    velX = 0
                else
                    touchMode = TOUCH_MOVE
                end
            end
        end
        if touchMode == TOUCH_IDLE or touchMode == TOUCH_MOVE then
            local page = Pages[Pages.page]
            if page ~= nil and page.zoom ~= nil then
                page.x = page.x + velX
                page.y = page.y + velY
            end
            if touchMode == TOUCH_IDLE then
                velY = velY * 0.9
                velX = velX * 0.9
            end
        elseif touchMode == TOUCH_SWIPE then
            offset.x = offset.x + velX
        end
        if touchMode ~= TOUCH_SWIPE then
            offset.x = offset.x / 1.2
        end
        if Pages[Pages.page].zoom ~= nil then
            if Pages[Pages.page].y - Pages[Pages.page].height / 2 * Pages[Pages.page].zoom > 0 then
                Pages[Pages.page].y = Pages[Pages.page].height / 2 * Pages[Pages.page].zoom
            elseif Pages[Pages.page].y + Pages[Pages.page].height / 2 * Pages[Pages.page].zoom < 544 then
                Pages[Pages.page].y = 544 - Pages[Pages.page].height / 2 * Pages[Pages.page].zoom
            end
            if Pages[Pages.page].mode ~= "Horizontal" or Pages[Pages.page].zoom*Pages[Pages.page].width > 960 then
                if Pages[Pages.page].zoom*Pages[Pages.page].width<=960 or Pages[Pages.page].zoom == Pages[Pages.page].min_zoom and Pages[Pages.page].mode ~= "Horizontal" then
                    pageMode = bit32.bor(PAGE_LEFT,PAGE_RIGHT)
                end
                if Pages[Pages.page].x - Pages[Pages.page].width / 2 * Pages[Pages.page].zoom >= 0 then
                    Pages[Pages.page].x = Pages[Pages.page].width / 2 * Pages[Pages.page].zoom
                    pageMode = bit32.bor(pageMode,PAGE_LEFT)
                elseif Pages[Pages.page].x + Pages[Pages.page].width / 2 * Pages[Pages.page].zoom <= 960 then
                    Pages[Pages.page].x = 960 - Pages[Pages.page].width / 2 * Pages[Pages.page].zoom
                    pageMode = bit32.bor(pageMode,PAGE_RIGHT)
                else
                    pageMode = PAGE_NONE
                end
            else
                Pages[Pages.page].x = 480
                pageMode = bit32.bor(PAGE_LEFT,PAGE_RIGHT)
            end
        end
    end,
    input = function (pad, oldpad)
        if Controls.check(pad, SCE_CTRL_RTRIGGER) then
            Scale (1.2, Pages[Pages.page])
        elseif Controls.check(pad, SCE_CTRL_LTRIGGER) then
            Scale (5/6, Pages[Pages.page])
        end
        if Touch.y ~= nil and OldTouch.y ~= nil then
            if touchMode ~= TOUCH_MULTI then
                if touchMode == TOUCH_IDLE then
                    touchTemp.x = Touch.x
                    touchTemp.y = Touch.y
                    touchMode = TOUCH_READ
                end
                velX = Touch.x - OldTouch.x
                velY = Touch.y - OldTouch.y
            end
            if Touch2.x ~= nil and OldTouch2.x ~= nil and Pages[Pages.page].zoom~=nil then
                touchMode = TOUCH_MULTI
                local old_zoom = Pages[Pages.page].zoom
                local center = { x = (Touch.x + Touch2.x) / 2, y = (Touch.y + Touch2.y) / 2 }
                local n = (math.sqrt((Touch.x - Touch2.x)*(Touch.x - Touch2.x)+(Touch.y - Touch2.y)*(Touch.y - Touch2.y))/math.sqrt((OldTouch.x - OldTouch2.x)*(OldTouch.x - OldTouch2.x)+(OldTouch.y - OldTouch2.y)*(OldTouch.y - OldTouch2.y)))
                Scale (n, Pages[Pages.page])
                n = Pages[Pages.page].zoom / old_zoom
                Pages[Pages.page].y = Pages[Pages.page].y - (center.y - 272) * (n - 1)
                Pages[Pages.page].x = Pages[Pages.page].x - (center.x - 480) * (n - 1)
            end
        else
            if touchMode == TOUCH_SWIPE then
                if offset.x > 100 and ChangePage(Pages.page - 1) then
                    offset.x = -960+offset.x
                    if Pages[Pages.page + 1] ~= nil and Pages[Pages.page + 1].zoom~=nil then
                        Pages[Pages.page + 1].x = 960+Pages[Pages.page + 1].width*Pages[Pages.page + 1].zoom/2
                    end
                elseif offset.x < -100 and ChangePage(Pages.page + 1) then
                    offset.x = 960+offset.x
                    if Pages[Pages.page - 1] ~= nil and Pages[Pages.page - 1].zoom~=nil then
                        Pages[Pages.page - 1].x = -Pages[Pages.page - 1].width*Pages[Pages.page - 1].zoom/2
                    end
                end
            end
            touchMode = TOUCH_IDLE
        end
        if Controls.check(pad, SCE_CTRL_UP) then
            Pages[Pages.page].y = Pages[Pages.page].y + 5*Pages[Pages.page].zoom
        elseif Controls.check(pad, SCE_CTRL_DOWN) then
            Pages[Pages.page].y = Pages[Pages.page].y - 5*Pages[Pages.page].zoom
        end
    end,
    load = function (pages_links)
        for i = 1, #Pages do
            if Pages[i] ~= nil then
                Net.remove (Pages[i], 'image')
                if Pages[i].image ~= nil then
                    Graphics.freeImage (Pages[i].image)
                end
            end
        end
        Pages = {}
        for i = 1, #pages_links do
            Pages[i] = { link = pages_links[i], x = 0, y = 0 }
        end
        ChangePage(1)
    end
}