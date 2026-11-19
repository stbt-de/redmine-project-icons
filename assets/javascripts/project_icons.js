/*
 * Project Icons – was serverseitig nicht geht:
 *
 *   Projektauswahl ("Zu einem Projekt springen"): Redmine baut sie in einer
 *   geschlossenen Methode und lädt Suchergebnisse per AJAX nach; die Icons
 *   kommen aus den Daten in <script id="project-icons-data"> (vom Plugin in
 *   den Kopf geschrieben, nur Projekte mit Icon oder Farbe).
 *
 *   Kalender: Redmine schreibt "Projekt - " als Text vor das Ticket, das
 *   Icon steht dahinter – es wird an den Anfang des Eintrags gesetzt.
 */
(function () {
  'use strict';

  var data;

  function readData() {
    var element = document.getElementById('project-icons-data');
    if (!element) return null;
    try {
      return JSON.parse(element.textContent);
    } catch (error) {
      return null;
    }
  }

  function iconElement(entry, size) {
    var icon;
    if (entry.icon) {
      icon = document.createElement('img');
      icon.src = entry.icon;
      icon.alt = '';
      icon.className = 'project-icon project-icon-image project-icon-' + size;
    } else {
      icon = document.createElement('span');
      icon.textContent = entry.letter || '';
      icon.setAttribute('aria-hidden', 'true');
      icon.className = 'project-icon project-icon-tile project-icon-' + size;
    }
    icon.style.setProperty('--project-icon-size', size + 'px');
    if (entry.color) icon.style.setProperty('--project-color', entry.color);
    return icon;
  }

  function entryFor(href) {
    if (!href || !data) return null;
    var path;
    try {
      path = new URL(href, window.location.href).pathname;
    } catch (error) {
      return null;
    }
    return data.projects[path] || null;
  }

  // Einträge der Auswahl (auch nachgeladene Suchergebnisse)
  function decorateItems(root) {
    root.querySelectorAll('#project-jump .drdn-items a').forEach(function (link) {
      if (link.querySelector('.project-icon')) return;
      var entry = entryFor(link.getAttribute('href'));
      if (!entry) return;
      var label = link.querySelector('span') || link;
      label.insertBefore(iconElement(entry, 16), label.firstChild);
    });
  }

  // Auslöser: Icon des aktuellen Projekts
  function decorateTrigger() {
    var trigger = document.querySelector('#project-jump .drdn-trigger');
    if (!trigger || trigger.querySelector('.project-icon') || !data.current) return;
    var entry = data.projects[data.current];
    if (!entry) return;
    trigger.insertBefore(iconElement(entry, 18), trigger.firstChild);
    trigger.classList.add('has-project-icon');
  }

  function moveCalendarIcons() {
    document.querySelectorAll('.cal div.issue > .project-icon').forEach(function (icon) {
      var entry = icon.parentElement;
      if (entry.firstChild !== icon) entry.insertBefore(icon, entry.firstChild);
    });
  }

  function init() {
    moveCalendarIcons();

    data = readData();
    var jump = document.getElementById('project-jump');
    if (!data || !jump) return;

    decorateTrigger();
    decorateItems(document);
    new MutationObserver(function () { decorateItems(jump); })
      .observe(jump, { childList: true, subtree: true });
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }
})();
