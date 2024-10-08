# How to X in js2lua

[js2lua](https://github.com/xiangnanscu/js2lua) repo.

Most of the things are easily translated without any problem, but there are a couple of cases where some special attention is required. This list might grow or shrink depending on whatever I find.

## Disable option

`js2lua --no-optionName file.js`, i.e `js2lua --no-index0to1 file.js`

Default options:
```ts
const defaultOptions = {
  debug: false,
  importStatementHoisting: true,
  transformToString: true,
  transformString: true,
  transformJSONStringify: true,
  transformJSONParse: true,
  transformParseFloat: true,
  transformParseInt: true,
  transformNumber: true,
  transformIsArray: true,
  transformConsoleLog: true,
  moduleExportsToReturn: true,
  index0To1: true,
  tryTranslateClass: true,
  disableUpdateExpressionCallback: true,
  renameCatchErrorIfNeeded: true,
  disableClassCall: true,
};
```

## Dot function invocation (awaiting answer in #2)

```js
some.func();
new some.func();
```

```lua
some:func()
some.func()
```

## Passing array objects

```js
func([ "someval" ]);
```

```lua
func({ "someval" })
```

## Add class methods

```js
string.prototype.replace = function() {}
```

```lua
function string:replace() end
```

## Recieve multiple values

AFAK not possible

<!-- ```js -->
<!-- let [a, b] = func(); -->
<!-- ``` -->
<!---->
<!-- ```lua -->
<!-- local a, b = func() -->
<!-- ``` -->

## Foreach

```js
for (let [key, value] in tbl) {}
```

```lua
for key, value, __ in pairs(tbl) do end
```

## Switch cases
Default case must be there and must have break in it otherwise it'll loop forever
