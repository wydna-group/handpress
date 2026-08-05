/* Lighting up the units a page belongs to.
 *
 * Shared by both renderings. It used to live only in the direct one, so the
 * TEI rendering grew the buttons and none of the behaviour -- the same fault
 * as the stylesheet before it, and for the same reason: one copy is the
 * maintained one and the other is not.
 *
 * Hover previews a unit; clicking pins it, so the highlight survives
 * scrolling. That matters more here than it would elsewhere, because the
 * point being made is that the eight pages printed on one sheet end up far
 * apart in the bound book -- you have to scroll to see it, and a highlight
 * that dies on mouse-out cannot show you.
 */
(function () {
  'use strict';

  var KINDS = ['leaf', 'sheet', 'forme'];
  var pinned = null;          // {kind: 'sheet', key: 'A1'}

  function leaves() {
    return document.querySelectorAll('.leaf');
  }

  function clear() {
    leaves().forEach(function (p) {
      KINDS.forEach(function (k) { p.classList.remove('lit-' + k); });
    });
    document.querySelectorAll('.unit span').forEach(function (b) {
      b.classList.remove('pinned');
    });
  }

  function light(kind, key) {
    leaves().forEach(function (p) {
      if (p.dataset[kind] === key) p.classList.add('lit-' + kind);
    });
  }

  function restore() {
    clear();
    if (!pinned) return;
    light(pinned.kind, pinned.key);
    document.querySelectorAll('.unit span[data-unit="' + pinned.kind + '"]')
      .forEach(function (b) {
        var leaf = b.closest('.leaf');
        if (leaf && leaf.dataset[pinned.kind] === pinned.key) {
          b.classList.add('pinned');
        }
      });
  }

  function keyOf(button) {
    var leaf = button.closest('.leaf');
    if (!leaf) return null;
    return { kind: button.dataset.unit, key: leaf.dataset[button.dataset.unit] };
  }

  document.addEventListener('mouseover', function (e) {
    var b = e.target.closest && e.target.closest('.unit span');
    if (!b) return;
    var u = keyOf(b);
    if (!u || !u.key) return;
    clear();
    light(u.kind, u.key);
  });

  document.addEventListener('mouseout', function (e) {
    var b = e.target.closest && e.target.closest('.unit span');
    if (!b) return;
    restore();
  });

  document.addEventListener('click', function (e) {
    var b = e.target.closest && e.target.closest('.unit span');
    if (!b) return;
    e.preventDefault();
    var u = keyOf(b);
    if (!u || !u.key) return;
    // clicking the pinned unit again lets it go
    if (pinned && pinned.kind === u.kind && pinned.key === u.key) {
      pinned = null;
    } else {
      pinned = u;
    }
    restore();
    if (pinned) announce(pinned);
  });

  /* Say what has been pinned and how many pages it holds, since the other
     pages of a sheet are usually off-screen. */
  function announce(u) {
    var n = 0;
    leaves().forEach(function (p) { if (p.dataset[u.kind] === u.key) n++; });
    var bar = document.getElementById('unit-note');
    if (!bar) {
      bar = document.createElement('div');
      bar.id = 'unit-note';
      document.body.appendChild(bar);
    }
    bar.innerHTML = '<b>' + u.kind + ' ' + u.key + '</b> — ' + n +
      ' page' + (n === 1 ? '' : 's') + ' lit. Scroll to see them; ' +
      'click again to release.';
    bar.className = 'shown ' + u.kind;
  }

  document.addEventListener('click', function (e) {
    if (e.target.closest && e.target.closest('.unit span')) return;
    if (!pinned) return;
    var bar = document.getElementById('unit-note');
    if (bar) bar.className = '';
  });
}());
