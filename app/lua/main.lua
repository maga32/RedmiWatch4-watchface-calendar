local lvgl = require("lvgl")

local globalWidth = lvgl.HOR_RES()
local globalHeight = lvgl.VER_RES()

local IMAGE_PATH = SCRIPT_PATH

local function imgPath(src)
    return IMAGE_PATH .. src
end

-- make image
local function Image(root, src, x, y, w, h)

    local t = {} -- create new table

    src = imgPath(src)

    t.widget = root:Image { src = src }

    if w == nil then
        w, h = t.widget:get_img_size()
    end

    t.w = w
    t.h = h
    t.x = x
    t.y = y

    function t:getWidth()
        return t.w
    end

    function t:getHeight()
        return t.h
    end

    function t:getX()
        return t.x
    end

    function t:getY()
        return t.y
    end

    t.widget:set {
        w = w,
        h = h,
        x = x,
        y = y
    }

    return t
end

local function createRoot()
    local property = {
        w = globalWidth,
        h = globalHeight,
        bg_color = 0,
        bg_opa = lvgl.OPA(0),
        border_width = 0,
        pad_all = 0
    }

    local scr = lvgl.Object(nil, property)
    scr:clear_flag(lvgl.FLAG.SCROLLABLE)
    return scr
end

local function start()
    -- 요일표시
    Image(rootView, "/days/days.png", 55, 0)

    -- 선택년월 위치셋팅
    calendarView.year[1]  = Image(rootView, "/days/blank.png", 250, 240)
    calendarView.year[2]  = Image(rootView, "/days/blank.png", 265, 240)
    Image(rootView, "/days/slash.png", 277, 240)
    calendarView.month[1] = Image(rootView, "/days/blank.png", 290, 240)
    calendarView.month[2] = Image(rootView, "/days/blank.png", 305, 240)

    local tmpX = 0
    local tmpY = 0

    -- 일 위치셋팅
    for i = 1, 37 do
        calendarView.day[i] = Image(rootView, "/days/blank.png", (tmpX%280)+55, (tmpY//7)*40+40)
        tmpX = tmpX + 40
        tmpY = tmpY + 1
    end

    nowYear = today.year
    nowMonth = today.month

    -- 이전달 선택
    local prevMonth = Image(rootView, "/days/blank.png", 0, 0, 95, 270)
    prevMonth.widget:add_flag(lvgl.FLAG.CLICKABLE)
    prevMonth.widget:onevent(lvgl.EVENT.CLICKED, function(obj, code)
        if nowMonth == 1 then
            nowMonth = 13
            nowYear = nowYear - 1
        end
        nowMonth = nowMonth - 1
        setCalendar()
    end)

    -- 다음달 선택
    local nextMonth = Image(rootView, "/days/blank.png", 295, 0, 95, 270)
    nextMonth.widget:add_flag(lvgl.FLAG.CLICKABLE)
    nextMonth.widget:onevent(lvgl.EVENT.CLICKED, function(obj, code)
        if nowMonth == 12 then
            nowMonth = 0
            nowYear = nowYear + 1
        end
        nowMonth = nowMonth + 1
        setCalendar()
    end)

    -- 날짜 새로고침
    local refresh = Image(rootView, "/days/blank.png", 95, 0, 200, 270)
    refresh.widget:add_flag(lvgl.FLAG.CLICKABLE)
    refresh.widget:onevent(lvgl.EVENT.CLICKED, function(obj, code)
        setCalendar()
    end)

    setCalendar()
end

function setCalendar()
    -- 날짜 리셋
    today = os.date('*t')

    -- 말일
    local lastDay = { 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 }
    if nowMonth == 2 then
        if nowYear % 4 == 0 and (nowYear % 100 ~= 0 or nowYear % 400 == 0) then
            lastDay[2] = 29
        end
    end

    -- 공휴일, 대체휴무 여부
    local holiday = {}
    holiday["1.1"]   = false -- 신정
    holiday["3.1"]   = true  -- 3.1절
    holiday["5.5"]   = true  -- 어린이날
    holiday["6.6"]   = false -- 현충일
    holiday["8.15"]  = true  -- 광복절
    holiday["10.3"]  = true  -- 개천절
    holiday["10.9"]  = true  -- 한글날
    holiday["12.25"] = true  -- 성탄절

    -- 구정, 석가탄신일, 추석 음력전환 추가
    local lunar = { {1,1}, {1,2}, {4,8}, {8,14}, {8,15}, {8,16} }
    for index, value in ipairs(lunar) do
        local tmpHoliday = lunarCalc(nowYear, value[1], value[2])

        -- 이미 공휴일이 아닌경우 공휴일로 추가
        if holiday[tmpHoliday[1] .. "." .. tmpHoliday[2]] == nil then
            holiday[tmpHoliday[1] .. "." .. tmpHoliday[2]] = true

        -- 이미 공휴일인경우 다음날을 대체휴무일로 지정
        else
            while true do
                if lastDay[tmpHoliday[1]] == tmpHoliday[2] then
                    tmpHoliday[1] = tmpHoliday[1] + 1
                    tmpHoliday[2] = 0
                end
                tmpHoliday[2] = tmpHoliday[2] + 1

                if holiday[tmpHoliday[1] .. "." .. tmpHoliday[2]] == nil then
                    holiday[tmpHoliday[1] .. "." .. tmpHoliday[2]] = false
                    break
                end
            end
            
        end
    end

    -- 구정(12월 말일) 추가
    local sulStart = lunarCalc(nowYear, 1, 1, true)
    if sulStart[2] == 1 then
        holiday["1.31"] = true
    else
        holiday[ sulStart[1] .. "." .. sulStart[2]-1 ] = true
    end

    -- 시작요일(일:0 ... 토:6)
    local startDay = getWeekday(nowYear, nowMonth, 1)

    -- 선택년월
    calendarView.year[1].widget:set  {src = imgPath("/days/" .. string.sub(nowYear, 3, 3) .. ".png")}
    calendarView.year[2].widget:set  {src = imgPath("/days/" .. string.sub(nowYear, 4, 4) .. ".png")}
    calendarView.month[1].widget:set {src = imgPath("/days/" .. getSeperatedMonth(nowMonth, 1) .. ".png")}
    calendarView.month[2].widget:set {src = imgPath("/days/" .. getSeperatedMonth(nowMonth, 2) .. ".png")}
    
    -- 리셋
    nowDayImg.widget:set { x = 390, y = 310 }
    local subHoliday = false

    -- 일
    for i = 1, 37 do
        -- 공백
        if i-startDay > lastDay[nowMonth] or i-startDay < 1 then
            calendarView.day[i].widget:set { src = imgPath("/days/blank.png") }

        -- 공휴일
        elseif holiday[nowMonth .. "." .. i-startDay] ~= nil then
            calendarView.day[i].widget:set { src = imgPath("/days/" .. i-startDay .. "_red.png") }
            -- 공휴일(대체휴무O) + 토,일요일 => 대체휴일 저장
            if holiday[nowMonth .. "." .. i-startDay] and (i%7 <= 1) then subHoliday = true end

        -- 일요일
        elseif i%7 == 1 then
            calendarView.day[i].widget:set { src = imgPath("/days/" .. i-startDay .. "_red.png") }

        -- 평일+대체휴일
        elseif subHoliday and i%7 ~= 0 then
            calendarView.day[i].widget:set { src = imgPath("/days/" .. i-startDay .. "_red.png") }
            subHoliday = false

        -- 평일
        else
            calendarView.day[i].widget:set { src = imgPath("/days/" .. i-startDay .. ".png") }
        end
        
        -- 오늘날짜 체크
        if nowMonth == today.month and nowYear == today.year and i-startDay == today.day then
             nowDayImg.widget:set { x = calendarView.day[i].getX()-1, y = calendarView.day[i].getY() }
        end
    end
end

function getSeperatedMonth(month, number)
    if string.len(month) == 1 then month = "0" .. month end
    return string.sub(month, number, number)
end

function getWeekday(year, month, day)
    if month < 3 then
        month = month + 12
        year = year - 1
    end
    local h = (day + math.floor((13 * (month + 1)) / 5) + year + math.floor(year / 4) - math.floor(year / 100) + math.floor(year / 400)) % 7
    -- 0:일, 1:월 ... 6:토
    local weekdays = {6, 0, 1, 2, 3, 4, 5}
    return weekdays[h+1]
end

-- 음력계산
local lunarMonthTable = {
    {2, 1, 1, 2, 3, 2, 2, 1, 2, 2, 2, 1},   -- 1998
    {2, 1, 1, 2, 1, 1, 2, 1, 2, 2, 2, 1},
    {2, 2, 1, 1, 2, 1, 1, 2, 1, 2, 2, 1},
    {2, 2, 2, 3, 2, 1, 1, 2, 1, 2, 1, 2},   -- 2001
    {2, 2, 1, 2, 1, 2, 1, 1, 2, 1, 2, 1},
    {2, 2, 1, 2, 2, 1, 2, 1, 1, 2, 1, 2},
    {1, 5, 2, 2, 1, 2, 1, 2, 1, 2, 1, 2},
    {1, 2, 1, 2, 1, 2, 2, 1, 2, 2, 1, 1},
    {2, 1, 2, 1, 2, 1, 5, 2, 2, 1, 2, 2},
    {1, 1, 2, 1, 1, 2, 1, 2, 2, 2, 1, 2},
    {2, 1, 1, 2, 1, 1, 2, 1, 2, 2, 1, 2},
    {2, 2, 1, 1, 5, 1, 2, 1, 2, 1, 2, 2},
    {2, 1, 2, 1, 2, 1, 1, 2, 1, 2, 1, 2},
    {2, 1, 2, 2, 1, 2, 1, 1, 2, 1, 2, 1},   -- 2011
    {2, 1, 6, 2, 1, 2, 1, 1, 2, 1, 2, 1},
    {2, 1, 2, 2, 1, 2, 1, 2, 1, 2, 1, 2},
    {1, 2, 1, 2, 1, 2, 1, 2, 5, 2, 1, 2},
    {1, 2, 1, 1, 2, 1, 2, 2, 2, 1, 2, 1},
    {2, 1, 2, 1, 1, 2, 1, 2, 2, 1, 2, 2},
    {2, 1, 1, 2, 3, 2, 1, 2, 1, 2, 2, 2},
    {1, 2, 1, 2, 1, 1, 2, 1, 2, 1, 2, 2},
    {2, 1, 2, 1, 2, 1, 1, 2, 1, 2, 1, 2},
    {2, 1, 2, 5, 2, 1, 1, 2, 1, 2, 1, 2},
    {1, 2, 2, 1, 2, 1, 2, 1, 2, 1, 2, 1},   -- 2021
    {2, 1, 2, 1, 2, 2, 1, 2, 1, 2, 1, 2},
    {1, 5, 2, 1, 2, 1, 2, 2, 1, 2, 1, 2},
    {1, 2, 1, 1, 2, 1, 2, 2, 1, 2, 2, 1},
    {2, 1, 2, 1, 1, 5, 2, 1, 2, 2, 2, 1},
    {2, 1, 2, 1, 1, 2, 1, 2, 1, 2, 2, 2},
    {1, 2, 1, 2, 1, 1, 2, 1, 1, 2, 2, 2},
    {1, 2, 2, 1, 5, 1, 2, 1, 1, 2, 2, 1},
    {2, 2, 1, 2, 2, 1, 1, 2, 1, 1, 2, 2},
    {1, 2, 1, 2, 2, 1, 2, 1, 2, 1, 2, 1},
    {2, 1, 5, 2, 1, 2, 2, 1, 2, 1, 2, 1},   -- 2031
    {2, 1, 1, 2, 1, 2, 2, 1, 2, 2, 1, 2},
    {1, 2, 1, 1, 2, 1, 2, 1, 2, 2, 5, 2},
    {1, 2, 1, 1, 2, 1, 2, 1, 2, 2, 2, 1},
    {2, 1, 2, 1, 1, 2, 1, 1, 2, 2, 1, 2},
    {2, 2, 1, 2, 1, 4, 1, 1, 2, 2, 1, 2},
    {2, 2, 1, 2, 1, 1, 2, 1, 1, 2, 1, 2},
    {2, 2, 1, 2, 1, 2, 1, 2, 1, 1, 2, 1},
    {2, 2, 1, 2, 5, 2, 1, 2, 1, 2, 1, 1},
    {2, 1, 2, 2, 1, 2, 2, 1, 2, 1, 2, 1},
    {2, 1, 1, 2, 1, 2, 2, 1, 2, 2, 1, 2},   -- 2041
    {1, 5, 1, 2, 1, 2, 1, 2, 2, 2, 1, 2},
    {1, 2, 1, 1, 2, 1, 1, 2, 2, 1, 2, 2}
}

function lunarCalc(year, month, day, forLastDay)
    local solYear, solMonth, solDay
    local lunYear, lunMonth, lunDay
    local lunLeapMonth, lunMonthDay
    local lunIndex

    local solMonthDay = {31, 0, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31}

    solYear = 2000
    solMonth = 1
    solDay = 1
    lunYear = 1999
    lunMonth = 11
    lunDay = 25
    lunLeapMonth = 0

    solMonthDay[2] = 29
    lunMonthDay = 30

    lunIndex = lunYear - 1997

    while true do
        if year == lunYear and month == lunMonth and day == lunDay and lunLeapMonth == 0 then
            return { solMonth, solDay }
        end

        -- add a day of solar calendar
        if solMonth == 12 and solDay == 31 then
            solYear = solYear + 1
            solMonth = 1
            solDay = 1

            -- set monthDay of Feb
            if solYear % 400 == 0 then
                solMonthDay[2] = 29
            elseif solYear % 100 == 0 then
                solMonthDay[2] = 28
            elseif solYear % 4 == 0 then
                solMonthDay[2] = 29
            else
                solMonthDay[2] = 28
            end

        elseif solMonthDay[solMonth] == solDay then
            solMonth = solMonth + 1
            solDay = 1
        else
            solDay = solDay + 1
        end

        -- add a day of lunar calendar
        if lunMonth == 12 and ((lunarMonthTable[lunIndex][lunMonth] == 1 and lunDay == 29) or (lunarMonthTable[lunIndex][lunMonth] == 2 and lunDay == 30)) then
            lunYear = lunYear + 1
            lunMonth = 1
            lunDay = 1

            lunIndex = lunYear - 1997

            if lunarMonthTable[lunIndex][lunMonth] == 1 then
                lunMonthDay = 29
            else
                lunMonthDay = 30
            end
        elseif lunDay == lunMonthDay then
            if lunarMonthTable[lunIndex][lunMonth] >= 3 and lunLeapMonth == 0 then
                lunDay = 1
                lunLeapMonth = 1
            else
                lunMonth = lunMonth + 1
                lunDay = 1
                lunLeapMonth = 0
            end

            if lunarMonthTable[lunIndex][lunMonth] == 1 then
                lunMonthDay = 29
            elseif lunarMonthTable[lunIndex][lunMonth] == 2 then
                lunMonthDay = 30
            elseif lunarMonthTable[lunIndex][lunMonth] == 3 then
                lunMonthDay = 29
            elseif lunarMonthTable[lunIndex][lunMonth] == 4 and lunLeapMonth == 0 then
                lunMonthDay = 29
            elseif lunarMonthTable[lunIndex][lunMonth] == 4 and lunLeapMonth == 1 then
                lunMonthDay = 30
            elseif lunarMonthTable[lunIndex][lunMonth] == 5 and lunLeapMonth == 0 then
                lunMonthDay = 30
            elseif lunarMonthTable[lunIndex][lunMonth] == 5 and lunLeapMonth == 1 then
                lunMonthDay = 29
            elseif lunarMonthTable[lunIndex][lunMonth] == 6 then
                lunMonthDay = 30
            end
        else
            lunDay = lunDay + 1
        end
    end
end

rootView = createRoot()
calendarView = {}
calendarView.year = {}
calendarView.month = {}
calendarView.day = {}

today = os.date('*t')
nowYear = ""
nowMonth = ""

nowDayImg = Image(rootView, "/days/nowDay.png", 390, 310)

start()