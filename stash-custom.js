// Custom JS for Stash — paste into Settings -> Interface -> Custom Javascript.
//
// Drives the cursor-follow glow defined in stash-custom-theme.css (the
// .grid-card::before radial-gradient). Plain "JS toggles a CSS custom
// property on mousemove" — no framework, works against Stash's existing
// rendered DOM without needing access to its React source.
//
// Stash's grid re-renders as you scan/filter/paginate, so this listens on
// the whole document (event delegation) instead of attaching to cards
// directly, which would go stale after the next render.
(function () {
  document.addEventListener("mousemove", function (e) {
    var card = e.target.closest(".grid-card");
    if (!card) return;
    var rect = card.getBoundingClientRect();
    var x = ((e.clientX - rect.left) / rect.width) * 100;
    var y = ((e.clientY - rect.top) / rect.height) * 100;
    card.style.setProperty("--mx", x + "%");
    card.style.setProperty("--my", y + "%");
  });
})();
