(function () {
  "use strict";

  var P = window.PROFILE || {};
  var $ = function (sel) { return document.querySelector(sel); };

  // Маленький помощник для создания элементов. Текст вставляется как текст, не как HTML.
  function h(tag, attrs, children) {
    var el = document.createElement(tag);
    if (attrs) {
      Object.keys(attrs).forEach(function (k) {
        if (k === "class") el.className = attrs[k];
        else if (k === "text") el.textContent = attrs[k];
        else if (k === "html") el.innerHTML = attrs[k]; // только для своих SVG-иконок
        else el.setAttribute(k, attrs[k]);
      });
    }
    (children || []).forEach(function (c) {
      if (c == null || c === false) return;
      el.appendChild(typeof c === "string" ? document.createTextNode(c) : c);
    });
    return el;
  }

  var ICONS = {
    telegram: '<path d="M21.5 3.5 2.8 10.7c-1 .4-1 1.8.1 2.1l4.6 1.4 1.8 5.6c.3.9 1.4 1.1 2 .4l2.6-2.7 4.6 3.4c.7.5 1.7.1 1.9-.7l3.2-15.2c.2-1-.8-1.9-1.8-1.5Z"/><path d="m7.5 14.2 10-7.2-7.6 8.6"/>',
    email: '<rect x="3" y="5" width="18" height="14" rx="3"/><path d="m4 7 8 6 8-6"/>',
    github: '<path d="M9 19c-4.3 1.4-4.3-2.5-6-3m12 5v-3.5c0-1 .1-1.4-.5-2 2.8-.3 5.5-1.4 5.5-6a4.6 4.6 0 0 0-1.3-3.2 4.2 4.2 0 0 0-.1-3.2s-1.1-.3-3.5 1.3a12.3 12.3 0 0 0-6.2 0C6.5 2.8 5.4 3.1 5.4 3.1a4.2 4.2 0 0 0-.1 3.2A4.6 4.6 0 0 0 4 9.5c0 4.6 2.7 5.7 5.5 6-.6.6-.6 1.2-.5 2V21"/>',
    phone: '<path d="M5 3h3l2 5-2.5 1.5a11 11 0 0 0 7 7L16 14l5 2v3a2 2 0 0 1-2 2A17 17 0 0 1 3 5a2 2 0 0 1 2-2Z"/>',
    vk: '<path d="M3 7h3.2c.4 3 1.7 5 3.3 5.6V7h3v3.3c1.5-.2 2.9-1.8 3.4-3.3H19c-.5 2.2-2 4-3.2 4.8 1.4.7 3 2.2 3.7 4.2h-3.3c-.7-1.6-2-2.8-3.7-3v3H12C6.5 18 3.3 14 3 7Z"/>',
    linkedin: '<rect x="3" y="3" width="18" height="18" rx="4"/><path d="M8 10.5V17M8 7.5v.01M12 17v-3.8c0-1.6 1-2.7 2.4-2.7S16.5 11.6 16.5 13v4M12 10.5V17"/>',
    instagram: '<rect x="3" y="3" width="18" height="18" rx="5"/><circle cx="12" cy="12" r="4"/><path d="M17.5 6.5v.01"/>',
    link: '<path d="M10 14a4 4 0 0 0 5.7 0l3-3a4 4 0 0 0-5.7-5.7l-1 1"/><path d="M14 10a4 4 0 0 0-5.7 0l-3 3a4 4 0 0 0 5.7 5.7l1-1"/>',
    arrow: '<path d="M7 17 17 7M8 7h9v9"/>',
  };
  function icon(name) {
    return h("svg", { viewBox: "0 0 24 24", "aria-hidden": "true", html: ICONS[name] || ICONS.link });
  }

  function initials(name) {
    return (name || "")
      .split(/\s+/)
      .filter(Boolean)
      .slice(0, 2)
      .map(function (w) { return w[0].toUpperCase(); })
      .join("");
  }

  function hide(sel) {
    var el = document.querySelector(sel);
    if (el) el.closest("section").hidden = true;
    var link = document.querySelector('.nav-links a[href="' + sel.replace("-list", "") + '"]');
    if (link) link.hidden = true;
  }

  // ---------- Наполнение ----------
  document.title = (P.name || "Резюме") + (P.role ? " — " + P.role : "");
  $("#logo").textContent = initials(P.name) || "Я";
  $("#heroName").textContent = P.name || "";
  $("#heroRole").textContent = P.role || "";
  $("#heroTagline").textContent = P.tagline || "";
  $("#footerName").textContent = P.name || "";
  $("#year").textContent = new Date().getFullYear();

  if (P.status) $("#status span:last-child").textContent = P.status;
  else $("#status").hidden = true;

  if (P.location) $("#heroLocation span").textContent = P.location;
  else $("#heroLocation").hidden = true;

  var avatar = $("#avatar");
  if (P.photo) {
    var img = h("img", { src: P.photo, alt: P.name || "Фото" });
    img.onerror = function () { avatar.textContent = initials(P.name); avatar.classList.remove("has-photo"); };
    avatar.appendChild(img);
    avatar.classList.add("has-photo");
  } else {
    avatar.textContent = initials(P.name);
  }

  var stats = $("#stats");
  (P.stats || []).forEach(function (s) {
    stats.appendChild(h("li", null, [h("strong", { text: s.value }), h("span", { text: s.label })]));
  });

  var about = $("#aboutText");
  (P.about || []).forEach(function (p) { about.appendChild(h("p", { text: p })); });
  var facts = $("#facts");
  (P.facts || []).forEach(function (f) {
    facts.appendChild(h("div", { class: "fact" }, [h("dt", { text: f.label }), h("dd", { text: f.value })]));
  });
  if (!(P.about || []).length && !(P.facts || []).length) hide("#about");

  var skills = $("#skills-list");
  (P.skills || []).forEach(function (g, gi) {
    var list = h("ul", { class: "skill-items" });
    (g.items || []).forEach(function (it) {
      var item = typeof it === "string" ? { name: it } : it;
      var dots = null;
      if (item.level) {
        dots = h("span", { class: "dots", "aria-label": "Уровень " + item.level + " из 5" });
        for (var i = 1; i <= 5; i++) dots.appendChild(h("i", { class: i <= item.level ? "on" : "" }));
      }
      list.appendChild(h("li", { class: "skill" + (dots ? "" : " chip") }, [h("span", { text: item.name }), dots]));
    });
    skills.appendChild(
      h("div", { class: "card skill-group reveal", style: "--d:" + gi * 80 + "ms" }, [
        h("h3", { text: g.group }),
        list,
      ])
    );
  });
  if (!(P.skills || []).length) hide("#skills-list");

  function timeline(sel, items) {
    var root = $(sel);
    (items || []).forEach(function (e, i) {
      var tags = null;
      if (e.tags && e.tags.length) {
        tags = h("ul", { class: "tags" }, e.tags.map(function (t) { return h("li", { text: t }); }));
      }
      root.appendChild(
        h("li", { class: "tl-item reveal", style: "--d:" + i * 80 + "ms" }, [
          h("span", { class: "tl-dot" }),
          h("div", { class: "card tl-card" }, [
            h("p", { class: "tl-period", text: e.period || "" }),
            h("h3", { text: e.title || "" }),
            e.place ? h("p", { class: "tl-place", text: e.place }) : null,
            e.description ? h("p", { class: "tl-desc", text: e.description }) : null,
            tags,
          ]),
        ])
      );
    });
    if (!(items || []).length) hide(sel);
  }
  timeline("#experience-list", P.experience);
  timeline("#education-list", P.education);

  var projects = $("#projects-list");
  (P.projects || []).forEach(function (p, i) {
    var link = p.link
      ? h("a", { class: "project-link", href: p.link, target: "_blank", rel: "noopener" }, [p.linkText || "Открыть", icon("arrow")])
      : null;
    projects.appendChild(
      h("article", { class: "card project reveal", style: "--d:" + i * 80 + "ms" }, [
        h("span", { class: "project-num", text: String(i + 1).padStart(2, "0") }),
        h("h3", { text: p.title || "" }),
        h("p", { text: p.description || "" }),
        p.tags && p.tags.length ? h("ul", { class: "tags" }, p.tags.map(function (t) { return h("li", { text: t }); })) : null,
        link,
      ])
    );
  });
  if (!(P.projects || []).length) hide("#projects-list");

  var contacts = $("#contacts-list");
  (P.contacts || []).forEach(function (c) {
    var ext = c.href && !/^(mailto|tel):/.test(c.href);
    contacts.appendChild(
      h("a", Object.assign({ class: "contact", href: c.href || "#" }, ext ? { target: "_blank", rel: "noopener" } : {}), [
        h("span", { class: "contact-icon" }, [icon(c.type)]),
        h("span", { class: "contact-text" }, [h("small", { text: c.label || "" }), h("span", { text: c.value || "" })]),
      ])
    );
  });

  // ---------- Тема ----------
  var root = document.documentElement;
  function currentTheme() {
    var t = root.getAttribute("data-theme");
    if (t) return t;
    return window.matchMedia("(prefers-color-scheme: light)").matches ? "light" : "dark";
  }
  $("#themeBtn").addEventListener("click", function () {
    var next = currentTheme() === "dark" ? "light" : "dark";
    root.setAttribute("data-theme", next);
    try { localStorage.setItem("theme", next); } catch (e) {}
  });

  // ---------- Мобильное меню ----------
  var burger = $("#burger");
  var nav = $(".nav");
  burger.addEventListener("click", function () {
    var open = nav.classList.toggle("open");
    burger.setAttribute("aria-expanded", open ? "true" : "false");
  });
  document.querySelectorAll(".nav-links a").forEach(function (a) {
    a.addEventListener("click", function () {
      nav.classList.remove("open");
      burger.setAttribute("aria-expanded", "false");
    });
  });

  // ---------- PDF ----------
  $("#printBtn").addEventListener("click", function () { window.print(); });

  // ---------- Анимации при прокрутке ----------
  var reduce = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
  var reveals = document.querySelectorAll(".reveal");
  if ("IntersectionObserver" in window && !reduce) {
    var io = new IntersectionObserver(function (entries) {
      entries.forEach(function (en) {
        if (en.isIntersecting) { en.target.classList.add("in"); io.unobserve(en.target); }
      });
    }, { threshold: 0.12, rootMargin: "0px 0px -40px 0px" });
    reveals.forEach(function (el) { io.observe(el); });
  } else {
    reveals.forEach(function (el) { el.classList.add("in"); });
  }

  // Подсветка активного раздела в меню
  var links = {};
  document.querySelectorAll(".nav-links a").forEach(function (a) { links[a.getAttribute("href").slice(1)] = a; });
  if ("IntersectionObserver" in window) {
    var so = new IntersectionObserver(function (entries) {
      entries.forEach(function (en) {
        var a = links[en.target.id];
        if (a && en.isIntersecting) {
          Object.keys(links).forEach(function (k) { links[k].classList.remove("active"); });
          a.classList.add("active");
        }
      });
    }, { rootMargin: "-45% 0px -50% 0px" });
    document.querySelectorAll("section[id]").forEach(function (s) { so.observe(s); });
  }

  // Полоса прогресса и тень у шапки
  var bar = $(".progress");
  function onScroll() {
    var max = document.documentElement.scrollHeight - window.innerHeight;
    bar.style.transform = "scaleX(" + (max > 0 ? window.scrollY / max : 0) + ")";
    nav.classList.toggle("scrolled", window.scrollY > 10);
  }
  window.addEventListener("scroll", onScroll, { passive: true });
  onScroll();

  // Свечение за курсором и наклон аватара (только мышь)
  if (window.matchMedia("(pointer: fine)").matches && !reduce) {
    var glow = $(".cursor-glow");
    window.addEventListener("pointermove", function (e) {
      glow.style.transform = "translate(" + e.clientX + "px," + e.clientY + "px)";
      glow.style.opacity = "1";
    });
    document.querySelectorAll(".card").forEach(function (card) {
      card.addEventListener("pointermove", function (e) {
        var r = card.getBoundingClientRect();
        card.style.setProperty("--mx", e.clientX - r.left + "px");
        card.style.setProperty("--my", e.clientY - r.top + "px");
      });
    });
    var wrap = $("#avatarWrap");
    wrap.addEventListener("pointermove", function (e) {
      var r = wrap.getBoundingClientRect();
      var x = (e.clientX - r.left) / r.width - 0.5;
      var y = (e.clientY - r.top) / r.height - 0.5;
      wrap.style.transform = "perspective(800px) rotateY(" + x * 14 + "deg) rotateX(" + -y * 14 + "deg)";
    });
    wrap.addEventListener("pointerleave", function () { wrap.style.transform = ""; });
  }
})();
