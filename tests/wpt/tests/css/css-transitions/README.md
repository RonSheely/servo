# CSSWG Compatible Tests #

## Hints ##

* en/disable vendor-prefixing in `./support/helper.js` see `addVendorPrefixes`
* remove extra `<length>` values to reduce test cases (and thus execution duration) in `./support.properties.js`, see `values.length`


## General Properties Test Concept ##

Using `support/property.js` test suites compile a list of animatable properties. `getPropertyTests()` (and the like) will expand the specification's `width: length, percentage` to `width: 1em, 1ex, 1px, … 1%` in order to test all possible value types. The propertyTests returned by `support/property.js` have the following general structure:

```javascript
{
  // name of the test
  "name": "background-color color(rgba)",
  // property that is being tested
  "property": "background-color",
  // styles to set on the parent container (usually #container)
  "parentStyle": {},
  // initial styles to set on the transition element (usually #transition)
  // may contain additional properties such as position: absolute; as required
  "from": {
    "background-color": "rgba(100,100,100,1)"
  },
  // styles to transition to
  "to": {
    "background-color": "rgba(10,10,10,0.4)"
  },
  // flags classifying property types,
  // currently only {discrete:true} for visbility
  "flags": {}
}
```

For each compiled test case the test runner identifies computed initial and target values. If they match, no transition will take place, because the property couldn't be parsed. If after starting the transition the computed style matches the target value, the browser applied that value immediately and no transition will take place. During the transition the computed style may match neither initial nor target value (unless it's a discrete transition), or there was no transition.

Besides value-assertions, the suites compare received TransitionEnd events. While the values are only matched against computed initial and target values, expected TransitionEnd events are declared explicitly. This can (and will) lead to some test failures that are arguably not a failure (mainly because the specification didn't cover the specific case). Transitioning `color` *may* (or not, depending on browser) also run a transition for `background-color`, as the latter's default value is `currentColor`. This suite considers those implicit transitions a failure. If it truly is a failure or not, should be decided in the specification (and tests updated accordingly).

Browsers supporting requestAnimationFrame can run a test in 100ms. Browsers that don't need a wider time frame to allow the not very dead-on-target setTimeout() to be triggered between TransitionStart and TransitionEnd. Low-end CPU devices also benefit from slower transitions. Since a 300 hundred tests, each lasting 500ms would require 2.5 minutes to run, tests are run concurrently, as they cannot affect each other. For low-end devices (e.g. iPad) too many parallel tests lead to global failure, because a single `requestAnimationFrame()` would have to iterate too many nodes, which is why the suite shards into slices of 50 parallel tests. Tests are run in an off-viewport container, to prevent you from having seizures.

To make individual tests a bit more readable, a lot of the test-functionality has been moved to external JavaScript files. All assertions reside within the test file itsel, though. Although they are mostly exact duplicates of other tests, it should help understanding what a test does (while abstracting away *how* it does it.)

### Debugging ###

1. reduce to the tests you want to take a closer look at - see `filterPropertyTests()` in `support/properties.js`
2. disable final cleanup by commenting out `done` and `teardown` callbacks
3. possibly increase the `duration` and disable the `#offscreen` (by simply naming it `#off-screen`)

## Tips to avoid test flakes ##

### Making style update deterministic ####

Timing characteristics vary widely across testing environments, and we need to
be careful about making assumptions about the state of the testing environment
to avoid race conditions.

Here is an example of a test with a race condition.

```css
# target {
  color: green;
  transition: color 300ms;
  transition-delay: -150ms;
}
```

```javascript
  test(() => {
    target.style.color = 'pink';
    assert_equals(getComputedStyle(target).color, ...);
  }, ...);
```
The value of color will differ depending on whether the color "change" was
captured as part of the initial style update. We cannot assume style and
layout are clean at the start of a test.

One way to fix this with the benefit of testing that a transition started is
as follows:

```javascript
  test(() => {
    assert_equals(document.getAnimations().length, 0,
                  'Initially no running animations');
    target.style.color = 'pink';
    assert_equals(document.getAnimations().length, 1,
                  'Color change triggers a CSS transition');
    assert_equals(getComputedStyle(target).color, ...);
  }, ...);
````

### Reftests and paint holding ###

To avoid the flash of white when a navigating between pages, browsers may
elect to freeze the contents until ready to render the page. All animations,
CSS transitions included, have a ready promise that is resolved when the
user agent has completed any set up and is ready to rendering the animation.

Rather than simply creating the transition and calling takeScreenshot, a safer
approach is as follows:

```javascript
window.onload = async () => {
   ... test setup including starting  any transitions ...

   const promises = document.getAnimations().map(anim => anim.ready);
   await Promise.all(promises);
   requestAnimationFrame(takeScreenshot);
};
```

### Reftests and avoiding animation drift ###

The animation API is largely asynchronous and an extra animation frame can
easily cause misalignment of a reftest with its reference image. One
approach to address the issue is to use a long duration animation with a
negative transition delay to set the position. If using this approach, we can
further reduce the potential for animation drift by using a step easing function
or freeze at the midpoint by using cubic-bezier(0, 1, 1, 0) combined with a
negative transition delay with a magnitude equal to half the duration.  Unless
critical for the test to be performed on running transitions, a safe alternative
is to pause the transitions.

```javascript
document.getAnimations().forEach(anim => anim.pause());
```

## Tips to reduce test runtime ##

When testing for transitionend, it is not necessary to let the animation run its
course. It may be tempting just to use a short duration animation, but safer is
to accelerate the animation via the web-animations API. This gives us precise
control over the test conditions.

```javascript
function fastForward(anim, progress) {
  anim.currentTime = anim.effect.getTiming().duration * progress;
}
```

If simply wanting to jump to the end of the transition, then calling
anim.finish() does the trick.  This fast forwarding trick is also really
useful for sampling a transition curve (testing whether a transition is
discrete or continuous for example).


## Unspecified Behavior ##

the following suites test behavior that is not covered in CSS3 Transitions (as of today):

* `properties-value-002.html` - verify value types transitionable but not specified for properties
* `properties-value-003.html` - verify transitionable properties thus far not specified at all
* `properties-value-implicit-001.html` - verify behavior for `em` based `<length>` properties when `font-size` is changed
* `events-006.html` - expect `TransitionEnd` event to be triggered and `event.pseudoElement` to be set properly
* `before-load-001.html` - expect transitions to be performed before document is fully loaded
* `hidden-container-001.html` - expect transitions to NOT be performed if they happen within hidden elements
* `detached-container-001.html` - expect transitions to NOT be performed if they happen outside of the document


## Yet To Be Tested ##

These are topics I have identifed in need of testing, but haven gotten around to testing them.

* Anything involving `<svg>`
  * well, maybe some day...
* proper execution of timing-functions - are the right property values set at a given time?
  * how exactly do I pinpoint a specific time to verify a property's value at time `t`?
  * need to implement cubic-bezier to actually calculate a property's value at time `t`?
* `selector:hover:before {}`
  * I have no clue how to trigger that from script

