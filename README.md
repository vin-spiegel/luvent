Luvent
======================================

Luvent는 [이벤트 중심 프로그래밍](https://ko.wikipedia.org/wiki/%EC%9D%B4%EB%B2%A4%ED%8A%B8_(%EC%BB%B4%ED%93%A8%ED%8C%85))을 지원하는 Lua용 라이브러리입니다.

설치
------------

```lua
local luvent = require "luvent"
```

Docs
-------------

### 핵심 ###

* **Event:** 이벤트 오브젝트는 `trigger(...)` 함수로 호출합니다

* **Action:** 다음 3개 요소 모두 이벤트와 연결할 수 있습니다

  1. 함수.
  2. 코루틴
  3. `__call` 메타 메소드가 포함된 테이블

* **Action ID:** `addAction()`은 나중에 저장할 수 있는 작업 ID를    반환합니다. 'disableAction()'과 같은 메서드와 함께 사용합니다. 아이디 대신 액션 자체를 사용할 수도 있습니다. 액션이 함수라면 '액션 또는 ID' 로 요청할 수 있습니다. 익명 함수가 주어진 경우 ID가 반환 됩니다. ID가 같으면 동일한 작업을 수행합니다.

### Basic Example ###

`newEvent()`로 생성하여 `trigger()`로 액션을 발동시킬수 있습니다. 액션을 발동시킬때 실행될 함수는 `addAction()`으로 추가할 수 있습니다

```lua
--  이 예제에는 middleclass가 필요합니다
--     https://github.com/kikito/middleclass
--
local class = require "middleclass"

local Luvent = require "Luvent"
local Enemy = class("Enemy")

-- 모든 살아있는 객체에 대한 래퍼런스가 담깁니다
Enemy.static.LIVING = {}

function Enemy:initialize(family, maxHP)
    self.family = family
    self.maxHP = maxHP
    self.HP = maxHP
    table.insert(Enemy.LIVING, self)
end

-- 몬스터가 죽을때마다 실행될 트리거
Enemy.static.onDie = Luvent.newEvent()

-- 'onDie' 트리거를 판단할 함수 
-- HP가 0 이 되면 `onDie` 액션 트리거
function Enemy:damage(damage)
    self.HP = self.HP - damage
    if self.HP <= 0 then
        Enemy.onDie:trigger(self)
    end
end


-- 여기서 `onDie`액션에 발동시킬 함수를 정의합니다
Enemy.onDie:addAction(
    function (enemy)
        for index,living_enemy in ipairs(Enemy.LIVING) do
            if enemy == living_enemy then
                table.remove(Enemy.LIVING, index)
                return
            end
        end
    end)


-- `onDie`액션에 같이 출력될 디버깅 함수
local debugAction = Enemy.onDie:addAction(
    function (enemy)
        print(string.format("Enemy %s died", enemy.family))
    end)


local bee = Enemy:new("Bee", 10)
local ladybug = Enemy:new("Ladybug", 1)

print(#Enemy.LIVING) --> Prints 2


ladybug:damage(100)
print(#Enemy.LIVING) --> Prints "1"

Enemy.onDie:removeAction(debugAction)
bee:damage(50)

print(#Enemy.LIVING)    -- Prints "0"
```

**Note:** Luvent discards all return values from action functions or anything that coroutines yield.

### Getting Information About Actions ###

Luvent는 액션 함수 또는 코루틴이 산출하는 모든 반환 값을 버립니다.

1. `getActionCount()` 메소드는 액션 수를 알려줍니다. *이것은 `trigger()`가 호출하는 작업의 수일 필요는 없습니다.* 이 메서드는 `addAction()` 메서드를 통해 이벤트와 관련된 고유한 작업의 수만 알려줍니다. Luvent를 사용하면 작업을 일시적으로 비활성화하고 실행을 지연할 수 있습니다. 즉, `trigger()`는 해당 작업이 여전히 이벤트와 연결되어 있어도 해당 작업을 호출하지 않습니다. 그렇기 때문에 `getActionCount()`에 의존하여 이벤트가 실행될 정확한 작업 수를 알 수 없습니다.

2. 메소드 `hasAction(action_or_id)`은 작업 또는 작업을 수락합니다.
   ID(즉, `addAction()`의 반환 값) 및 `boolean` 반환 액션이 이벤트의 일부인지 여부를 나타냅니다. 그러나 `hasAction()`이 `true` 를 반환한다고 해서 다음을 보장하는 것은 아닙니다. 이벤트는 영향을 미치는 동일한 이유로 해당 작업을 호출합니다. `getActionCount()`.

### Enabling and Disabling Actions ###

* `getActionCount()` 는 이벤트가 얼마나 많은 작업을 수행하는지 알려줍니다.
그러나 이것이 반드시 호출할 작업의 수는 아닙니다. 이벤트를 트리거하면. 액션을 추가하면 Luvent가 기본적으로 활성화합니다. 


    ```lua
    local debugAction = Enemy.onDie:addAction(
        function (enemy)
            print(string.format("Enemy %s died", enemy.family))
        end)

    -- ...Later in the code...

    Enemy.onDie:disableAction(debugAction)
    ```

`disableAction`은 작업을 일시적으로만 비활성화 시킵니다 `enableAction()` 을 이용하여 다시 사용할 수 있습니다.
`removeAction()` 은 작업을 완전히 지웁니다

### Action Intervals ###

이벤트에는 *시간 간격* 이 있는 작업이 있을 수 있습니다. 작업이 다시 실행되기 전에 경과해야 하는 시간입니다. Luvent를 사용하면 간격을 초 단위로 정의할 수 있습니다.


```lua
-- In this example you have a game where the AI has an 'onThink' event.
-- You want the AI to do many things on that event, but some of them
-- may be expensive in terms of performance.  So there may be actions
-- which you only want to run every so many seconds.

local function someSlowFunction(ai)
    -- You do something with the AI here that can take a while and so
    -- you do not want to always run this action.
end

AI.onThink:addAction(someSlowFunction)

-- Now you can tell the event to execute the action every ten seconds.
AI.onThink:setActionInterval(someSlowFunction, 10)

-- No matter how often you trigger the event, someSlowFunction() will
-- only run once per ten seconds.
while true do
    AI.onThink:trigger()
end
```

작업에는 기본적으로 간격이 없습니다. `removeActionInterval()`은 작업들 간 시간 간격을 제거합니다.

### Prioritizing Actions ###

luvent 의 디폴트 값은 우선순위를 설정하지 않습니다. 하지만 다음과 같이 행동에 숫자 우선 순위를 할당할 수 있습니다. 우선순위가 설정된 경우 Luvent는
가장 높은 것부터 우선 순위의 순서에 따라 작업을 호출합니다.

```lua
-- Let's say you are writing an AI for a board game.  You have an
-- 'onMove' event which triggers a variety of actions.  The functions
-- have stub implementations for the sake of brevity.

AI.onMove = Luvent.newEvent()

local function makeMove(player, board) end
local function analyzeCurrentPosition(player, board) end
local function searchPatternDatabase(player, board) end
local function estimateScore(player, board) end

AI.onMove:addAction(makeMove)
AI.onMove:addAction(analyzeCurrentPosition)
AI.onMove:addAction(searchPatternDatabase)
AI.onMove:addAction(estimateScore)

-- At this point you have given no action any explicit priority.  So if
-- you trigger the event now then there is no guarantee about the order
-- in which Luvent will call each action.  You cannot even rely on the
-- event to call the actions in the order you added them.

AI.onMove:setActionPriority(makeMove, 2)
AI.onMove:setActionPriority(analyzeCurrentPosition, 4)
AI.onMove:setActionPriority(searchPatternDatabase, 3)
AI.onMove:setActionPriority(estimateScore, 1)
```

>위와 같은 경우에서 `AI.onMove:trigger()`는 다음 순서로 작업을 호출합니다.

1. `analyzeCurrentPosition()`
2. `searchPatternDatabase()`
3. `makeMove()`
4. `estimateScore()`

이러한 작업에 `removeActionPriority()`를 사용하여 배치할 수 있습니다.
Luvent의 기본값인 목록 맨 아래에 다시 표시합니다. 명시적인 우선 순위가 없는 작업은 마지막으로 실행됩니다. 작업 우선 순위를 같은 숫자로 설정하지 마세요. 

### Action Limits ###

액션의 횟수를 제한해야 하는 상황이 있습니다. `limit` 를 이용하여 액션의 횟수를 제한할 수 있스빈다

```lua
-- In this example you are working with an 'onDeath' event for players
-- in a game.  The first time the player dies you want to save his or
-- her score.  But the player can continue after that and you do not
-- want to record scores after the first continue.  And so you want
-- the action for saving the score to run only once.

Game.onDeath = Luvent.newEvent()

local function saveScore(player) end
local function promptForContinue(player) end

Game.onDeath:addAction(saveScore)
Game.onDeath:addAction(promptForContinue)

-- This tells Luvent the limit for the action, i.e. the number of
-- times to invoke the action before automatically removing it.  This
-- specific example causes the event to call saveScore() only once and
-- then it will remove the action from 'onDeath'.
Game.onDeath:setActionLimit(saveScore, 1)

-- And for sanity this makes sure to save the score first by giving it
-- a higher priority than promptForContinue().  The number ten here is
-- an arbitrary choice; it just needs to be a number greater than zero
-- since there is no explicit priority for the other action.
Game.onDeath:setActionPriority(saveScore, 10)
```

`Game.onDeath:trigger()` 에 대한 첫 번째 호출은 `saveScore()`를 호출합니다. 그리고 `promptForContinue()`. 그 이후의 모든 `trigger()` 호출은 두 번째 작업부터 호출합니다. 행동이 한계에 도달하면 Luvent는 `removeAction()`을 로 지워줍니다. 

### Getters ###

1. `getActionTriggerLimit(action_or_id)`
2. `getActionInterval(action_or_id)`
3. `getActionPriority(action_or_id)`

### Looping Over Actions ###

* 반복문을 이용하여 루프작업을 할 수도 있습니다

    ```lua
    -- Continuing the previous example, this loop temporarily disables all
    -- actions attached to the event.
    for action in Game.onDie:allActions() do
        Game.onDie:disableAction(action)
    end
    ```

>다음과 같이 각 작업에 대해 하나의 함수 또는 메서드만 호출해야 하는 경우  `forEachAction()`을 사용할 수 있습니다. 첫번째 인자는 매겨변수, 두번째 인자는 각 작업에 대해 한 번 호출되는 함수입니다. 

1. The Event object containing the actions.

2. The ID of the current action.

    >이 요구 사항은 해당 메서드를 `forEachAction()`에 전달하여 각 작업에 대한 메서드를 호출할 수 있도록 합니다. 예를 들어 다음과 같이 이전 루프를 다시 작성할 수 있습니다.

    ```lua
    Game.onDie:forEachAction(Luvent.disableAction)
    ```

    *반복 중에 액션을 추가하거나 제거하면 오류가 생깁니다.*

    >`allActions()`를 사용하거나 `forEachAction()`을 통해 루프 중에 `addAction()`, `removeAction()` 또는 `removeAllActions()`를 호출할 수 없습니다. 

### Complete List of the Public API ###

- API 목록

    * `trigger(...)`
    * `addAction(action)`
    * `removeAction(action_or_id)`
    * `removeAllActions()`
    * `getActionCount()`
    * `hasAction(action_or_id)`
    * `isActionEnabled(action_or_id)`
    * `enableAction(action_or_id)`
    * `disableAction(action_or_id)`
    * `setActionPriority(action_or_id, integer)`
    * `removeActionPriority(action_or_id)`
    * `setActionTriggerLimit(action_or_id, integer)`
    * `removeActionTriggerLimit(action_or_id)`
    * `setActionInterval(action_or_id, integer)`
    * `removeActionInterval(action_or_id)`
    * `allActions()`
    * `forEachAction(callable)`
    * `getActionTriggerLimit(action_or_id)`
    * `getActionInterval(action_or_id)`
    * `getActionPriority(action_or_id)`


Acknowledgments and Alternatives
--------------------------------

참고 및 비교자료

* [Custom Event Support](https://github.com/benbeltran/custom_event_support.lua) by Ben Beltran
* [Emitter](https://github.com/friesencr/lua_emitter) by Chris Friesen
* [Lua-Event](https://github.com/slime73/Lua-Event) by Alex Szpakowski
* [Lua-Events](https://github.com/syntruth/Lua-Events) by syntruth
* [Lua-Events](https://github.com/wscherphof/lua-events) by Wouter Scherphof
* [events.lua](https://github.com/mvader/events.lua) by José Miguel Molina


License
-------

[The MIT License](http://opensource.org/licenses/MIT)

Copyright 2013–2015 Eric James Michael Ritz



[Lua]: http://lua.org/
[EDP]: http://en.wikipedia.org/wiki/Event-driven_programming
[EventLib]: https://github.com/mlnlover11/EventLib
[Node.js]: http://nodejs.org/
[LuaJIT]: http://luajit.org/
[LDoc]: http://stevedonovan.github.io/ldoc/
[Busted]: http://olivinelabs.com/busted/
[coroutine]: http://www.lua.org/manual/5.2/manual.html#2.6
[metamethod]: http://www.lua.org/manual/5.2/manual.html#2.4
[LÖVE]: http://love2d.org/
[GNU Make]: https://www.gnu.org/software/make/
[Luacheck]: https://github.com/mpeterv/luacheck
[Travis-CI-Badge]: https://travis-ci.org/ejmr/Luvent.svg
[Travis-CI]: https://travis-ci.org/ejmr/Luvent
