/* The behaviour of the facsimile.
 *
 * Shared by both renderings. It used to live only in the direct one, so the
 * TEI rendering grew the buttons and none of the behaviour -- the same fault
 * as the stylesheet before it, and for the same reason: one copy is the
 * maintained one and the other is not.
 *
 * Four things happen here, and each answers a question the page could not
 * answer before:
 *
 *   views      a book of sixty leaves has more to say about itself than a
 *              single scroll can hold, so the make-up, the evidence and the
 *              copies are panels of their own rather than an appendix.
 *   units      hovering a unit lights the other pages of it. The point being
 *              made is that eight pages printed on one sheet end up far apart
 *              in the bound book -- you have to scroll to see it, and a
 *              highlight that dies on mouse-out cannot show you.
 *   filters    ten kinds of departure marked at once is an apparatus nobody
 *              can read. Any kind can be switched off.
 *   map        one tick per page: where you are, and a way to anywhere.
 */
(function () {
  'use strict';

  var KINDS = ['leaf', 'sheet', 'forme'];
  var pinned = null;          // {kind: 'sheet', key: 'A1'}

  function $(sel, root) { return (root || document).querySelector(sel); }
  function $$(sel, root) {
    return Array.prototype.slice.call((root || document).querySelectorAll(sel));
  }

  function leaves() { return $$('.leaf'); }

  /* ---- the units a page belongs to ----------------------------------- */

  function clear() {
    leaves().forEach(function (p) {
      KINDS.forEach(function (k) { p.classList.remove('lit-' + k); });
    });
    $$('.unit span').forEach(function (b) { b.classList.remove('pinned'); });
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
    $$('.unit span[data-unit="' + pinned.kind + '"]').forEach(function (b) {
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
    if (b) restore();
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

  /* ---- everything that answers to a click ----------------------------- */

  document.addEventListener('click', function (e) {
    var t = e.target;

    /* a unit button */
    var b = t.closest && t.closest('.unit span');
    if (b) {
      e.preventDefault();
      var u = keyOf(b);
      if (!u || !u.key) return;
      /* clicking the pinned unit again lets it go */
      pinned = (pinned && pinned.kind === u.kind && pinned.key === u.key)
        ? null : u;
      restore();
      if (pinned) announce(pinned);
      return;
    }

    /* switching view */
    var v = t.closest && t.closest('[data-view]');
    if (v && v.tagName === 'BUTTON') {
      showView(v.dataset.view);
      return;
    }

    /* the plain/marked toggle */
    if (t.dataset && t.dataset.toggle === 'plain') {
      document.body.classList.toggle('plain');
      t.textContent = document.body.classList.contains('plain')
        ? 'show the marks' : 'show the page plain';
      return;
    }

    /* a filter */
    var f = t.closest && t.closest('.filter');
    if (f) {
      /* let the checkbox settle first, then follow it */
      setTimeout(function () {
        var box = $('input', f);
        f.classList.toggle('on', box.checked);
        document.body.classList.toggle('hide-' + f.dataset.cls, !box.checked);
      }, 0);
      return;
    }

    /* a map tick: jump, and do not leave a hash in the history */
    var tick = t.closest && t.closest('.tick');
    if (tick) {
      e.preventDefault();
      var target = document.getElementById(tick.getAttribute('href').slice(1));
      if (target) {
        showView('book');
        target.scrollIntoView({ behavior: 'smooth', block: 'center' });
        target.classList.add('found');
        setTimeout(function () { target.classList.remove('found'); }, 1600);
      }
      return;
    }

    /* clicking off releases the pinned unit's note */
    if (pinned) {
      var bar = document.getElementById('unit-note');
      if (bar) bar.className = '';
    }
  });

  /* ---- views ---------------------------------------------------------- */

  function showView(name) {
    $$('.view').forEach(function (s) {
      s.classList.toggle('on', s.dataset.view === name);
    });
    $$('#views button').forEach(function (btn) {
      btn.classList.toggle('on', btn.dataset.view === name);
    });
    if (name !== 'book') window.scrollTo({ top: 0, behavior: 'auto' });
  }

  /* ---- counts beside each filter --------------------------------------- */
  /* A filter that does not say how much it is hiding is a switch in the dark. */

  function countMarks() {
    $$('.filters .filter').forEach(function (f) {
      var n = $$('.' + f.dataset.cls, $('.view[data-view="book"]')).length;
      var slot = $('.cnt', f);
      if (slot) slot.textContent = n ? n.toLocaleString() : '0';
      if (!n) f.classList.add('empty');
    });
  }

  /* ---- the map: show where the reader is ------------------------------ */

  function trackPosition() {
    var ticks = $$('.tick');
    if (!ticks.length || !('IntersectionObserver' in window)) return;
    var byId = {};
    ticks.forEach(function (t) { byId[t.dataset.sig] = t; });
    var seen = new Set();
    var io = new IntersectionObserver(function (entries) {
      entries.forEach(function (en) {
        var sig = en.target.id.slice(3);
        if (en.isIntersecting) seen.add(sig); else seen.delete(sig);
      });
      ticks.forEach(function (t) {
        t.classList.toggle('here', seen.has(t.dataset.sig));
      });
    }, { rootMargin: '-45% 0px -45% 0px' });
    leaves().forEach(function (l) { if (l.id) io.observe(l); });
  }

  /* ---- the quire diagram: light a leaf and its conjugate --------------- */

  function conjugates() {
    $$('.quire').forEach(function (q) {
      var folds = $$('.fold', q);
      folds.forEach(function (f) {
        f.addEventListener('mouseenter', function () {
          var j = parseInt(f.dataset.conj, 10) - 1;
          f.classList.add('lit');
          if (folds[j]) folds[j].classList.add('lit');
        });
        f.addEventListener('mouseleave', function () {
          folds.forEach(function (g) { g.classList.remove('lit'); });
        });
      });
    });
  }

  /* Show the book as one named copy reads it.
   *
   * Every press variant divides the edition, and the page carries all the
   * readings: each altered word has data-r0, data-r1 ... and a data-m
   * pointing at the pattern that says which copy takes which. The patterns
   * are shared -- one per corrected forme, not one per word -- because a
   * forme is what a variant belongs to.
   *
   * data-set names the reading whose TYPE this word describes. Only that one
   * may keep its glyph and its damaged sorts: hp:glyph, hp:sorts and the
   * position are facts about the metal that stood in the forme, and the other
   * state was never set as type at all. Showing the marks beside the other
   * reading would put the type of one state under the words of another, and
   * the sorts are indexed by position, so they would land on whatever letters
   * happened to sit at those offsets.
   */
  function showCopy(id) {
    var copies = window.HP_COPIES || [], masks = window.HP_MASKS || [];
    var ci = copies.indexOf(id);
    if (ci < 0) return;
    $$('[data-m]').forEach(function (w) {
      var mask = masks[+w.dataset.m];
      if (!mask) return;
      var r = mask.charCodeAt(ci) - 48;
      if (w.dataset.set !== undefined && +w.dataset.set === r) {
        w.innerHTML = w.dataset.h;
      } else {
        w.textContent = w.dataset['r' + r] || '';
      }
      w.classList.toggle('other-state',
                         w.dataset.set === undefined || +w.dataset.set !== r);
    });
    document.documentElement.setAttribute('data-copy', id);
  }

  function witnessPicker() {
    var sel = $('#witness');
    if (!sel) return;
    sel.addEventListener('change', function () { showCopy(sel.value); });
    showCopy(sel.value);
  }

  function init() {
    countMarks();
    trackPosition();
    conjugates();
    witnessPicker();
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }
}());
