import 'dart:async';
import 'dart:html';

const _defaultSelector = ".js-fr-dialogmodal";
const _focusableSelectors = const [
  'a[href]',
  'area[href]',
  'input:not([disabled])',
  'select:not([disabled])',
  'textarea:not([disabled])',
  'button:not([disabled])',
  'iframe',
  'object',
  'embed',
  '[contenteditable]',
  '[tabindex]:not([tabindex^="-"])'
];

class ModalDialog {
  final String selector;
  final String modalSelector;
  final String openSelector;
  final String closeSelector;
  final String readyClass;
  final String activeClass;
  final bool isAlert;
  Element _currButtonOpen;
  Element _currModal;
  List _containers = [];
  List _focusableElements = [];

  ModalDialog(
      {this.selector: _defaultSelector,
      this.modalSelector: "${_defaultSelector}-modal",
      this.openSelector: "${_defaultSelector}-open",
      this.closeSelector: "${_defaultSelector}-close",
      this.readyClass: "fr-dialogmodal--is-ready",
      this.activeClass: "fr-dialogmodal--is-active",
      this.isAlert: false}) {
    _containers = new List.from(querySelectorAll(selector));
  }

  Future init() async {
    Completer c = new Completer();

    if (_containers.isEmpty) {
      c.completeError("No modal dialogs found");
    }

    for (var container in _containers) {
      await _addA11y(container);
      await _bindOpenPointers(container);
      container.classes.add(readyClass);
    }

    c.complete();
    return c.future;
  }

  Future destroy() async {
    Completer c = new Completer();

    if (_containers.isEmpty) {
      c.completeError("No modal dialogs found");
    }

    for (var container in _containers) {
      var modal = container.querySelector(modalSelector);
      modal.attributes.remove("tabindex");
      await _removeA11y(container);
      _unbindOpenPointers(container);
      _unbindClosePointer();
      _unbindContainerPointer();
      container.classes.removeAll([readyClass, activeClass]);
    }
    _unbindDocKey();

    c.complete();
    return c.future;
  }

  Future _addA11y(Element container) {
    Completer c = new Completer();

    var modal = container.querySelector(modalSelector);
    if (modal == null) {
      c.completeError("No selector ${modalSelector} present");
    }

    var role = isAlert ? "alertdialog" : "dialog";
    container.setAttribute("aria-hidden", "true");
    modal.setAttribute("role", role);

    c.complete();
    return c.future;
  }

  Future _removeA11y(Element container) {
    Completer c = new Completer();

    var modal = container.querySelector(modalSelector);
    if (modal == null) {
      c.completeError("No selector ${modalSelector} present");
    }

    container.attributes.remove("aria-hidden");
    modal.attributes.remove("role");

    c.complete();
    return c.future;
  }

  //TODO error?
  List<StreamSubscription> _onOpenSubscription = [];
  Future _bindOpenPointers(Element container) async {
    Completer c = new Completer();

    var id = container.getAttribute("id");
    var buttons = new List.from(
        querySelectorAll("${openSelector}[aria-controls='${id}']"));

    for (Element button in buttons) {
      _onOpenSubscription.add(button.onClick.listen(_eventOpenPointer));
    }

    c.complete();
    return c.future;
  }

  _unbindOpenPointers(Element container) {
    for (var subscription in _onOpenSubscription) {
      subscription.cancel();
    }
  }

  StreamSubscription _onKeyDownSubscription;
  _bindDocKey(n) {
    _onKeyDownSubscription = document.onKeyDown.listen(_eventDocKey);
  }

  _unbindDocKey() {
    _onKeyDownSubscription.cancel();
  }

  StreamSubscription _onCloseSubscription;
  _bindClosePointer([Element modal]) {
    modal = _currModal;
    var button = modal.querySelector(closeSelector);
    _onCloseSubscription = button.onClick.listen(_eventClosePointer);
  }

  _unbindClosePointer() {
    _onCloseSubscription.cancel();
  }

  StreamSubscription _onClickContainerSubscription;
  _bindContainerPointer([Element modal]) {
    modal = _currModal;
    var container = modal.parent;
    _onClickContainerSubscription =
        container.onClick.listen(_eventContainerPointer);
  }

  _unbindContainerPointer() {
    _onClickContainerSubscription.cancel();
  }

  _eventOpenPointer(e) {
    Element button = e.target;
    var container = querySelector("#${button.getAttribute("aria-controls")}");
    var modal = container.querySelector(modalSelector);

    _currButtonOpen = button;
    _currModal = modal;
    _showModal(container, modal);
  }

  _eventClosePointer(e) {
    _hideModal(_currModal);
  }

  _eventContainerPointer(e) {
    var container = _currModal.parent;
    if (e.target == container) _hideModal(_currModal);
  }

  _eventDocKey(e) {
    //	ESC key
    if (e.keyCode == 27) _hideModal(_currModal);
    //	TAB key
    if (e.keyCode == 9) _handleTabEvent(e);
  }

  _showModal(Element container, Element modal) async {
    container.setAttribute("aria-hidden", "false");
    modal.setAttribute("tabindex", "-1");
    _focusableElements =
        new List.from(modal.querySelectorAll(_focusableSelectors.join(",")));

    if (_focusableElements.isNotEmpty)
      _focusableElements[0].focus();
    else
      modal.focus();

    await _nextPaint(_bindDocKey);
    await _nextPaint(_bindClosePointer);
    if (!isAlert) {
      await _nextPaint(_bindContainerPointer);
    }
    modal.scrollTop = 0;
    container.classes.add(activeClass);
  }

  _hideModal(Element modal, [bool returnfocus = true]) {
    var container = modal.parent;
    container.setAttribute("aria-hidden", "true");
    modal.attributes.remove("tabindex");
    _unbindDocKey();
    _unbindClosePointer();

    if (!isAlert) {
      _unbindContainerPointer();
    }
    container.classes.remove(activeClass);

    if (returnfocus) {
      _currButtonOpen.focus();
      _currButtonOpen = null;
    }
  }

  _handleTabEvent(e) {
    var focusedIndex = _focusableElements.indexOf(document.activeElement);

    if (e.shiftKey && focusedIndex <= 0) {
      _focusableElements.last.focus();
      e.preventDefault();
    } else if (!e.shiftKey && focusedIndex == _focusableElements.length - 1) {
      _focusableElements.first.focus();
      e.preventDefault();
    }
  }

  Future _nextPaint(Function f) {
    return window.animationFrame.then(f);
  }
}
