/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/. */

// https://html.spec.whatwg.org/multipage/#htmlvideoelement
[Exposed=Window]
interface HTMLVideoElement : HTMLMediaElement {
  [HTMLConstructor] constructor();

  // [CEReactions]
  //          attribute unsigned long width;
  // [CEReactions]
  //          attribute unsigned long height;
  readonly attribute unsigned long videoWidth;
  readonly attribute unsigned long videoHeight;
  [CEReactions] attribute DOMString poster;
};

partial interface HTMLVideoElement {
  [Pref="media_testing_enabled"]
  attribute EventHandler onpostershown;
};
