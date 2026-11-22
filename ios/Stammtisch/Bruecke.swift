import UIKit
import WebKit

/// Brücke zwischen Web-App und App. Vor dem ersten Skript der Seite steht `window.StammtischNative`
/// bereit (Gegenstück: src/lib/nativ.ts im Repo stammtisch). Aufrufe laufen über
/// `webkit.messageHandlers.stammtisch` und werden per `_fertig(id, ok, wert)` beantwortet.
/// Dazu kommen Ersatz für navigator.vibrate (Haptik) und navigator.share (Teilen-Menü).
enum Bruecke {
    static let handlerName = "stammtisch"

    static var skript: String {
        """
        (function () {
          if (window.StammtischNative) return;
          var offen = {}, n = 0;
          function call(name, args) {
            return new Promise(function (resolve, reject) {
              var id = String(++n);
              offen[id] = { resolve: resolve, reject: reject };
              window.webkit.messageHandlers.\(handlerName).postMessage({ id: id, name: name, args: args || {} });
            });
          }
          Object.defineProperty(window, 'StammtischNative', {
            value: Object.freeze({
              platform: 'ios',
              version: \(jsString(AppKonfig.version)),
              call: call,
              _fertig: function (id, ok, wert) {
                var p = offen[id];
                if (!p) return;
                delete offen[id];
                if (ok) p.resolve(wert); else p.reject(new Error(String(wert)));
              }
            })
          });

          // Vibration gibt es in iOS-WebViews nicht: Muster wie [200, 80, 300] als Haptik abspielen
          if (typeof navigator.vibrate !== 'function') {
            navigator.vibrate = function (muster) {
              var liste = Array.isArray(muster) ? muster : [muster];
              var t = 0;
              liste.forEach(function (d, i) {
                d = Number(d) || 0;
                if (i % 2 === 0 && d > 0) {
                  var staerke = d >= 150 ? 'heavy' : d >= 60 ? 'medium' : 'light';
                  setTimeout(function () { call('haptic', { style: staerke }).catch(function () {}); }, t);
                }
                t += d;
              });
              return true;
            };
          }

          // Teilen-Menü von iOS
          if (typeof navigator.share !== 'function') {
            navigator.share = function (daten) {
              daten = daten || {};
              return call('share', { title: daten.title || '', text: daten.text || '', url: daten.url || '' }).then(function (r) {
                if (r !== 'completed') throw new DOMException('Teilen abgebrochen', 'AbortError');
              });
            };
            navigator.canShare = function () { return true; };
          }
        })();
        """
    }

    static func jsString(_ s: String) -> String {
        let daten = try? JSONSerialization.data(withJSONObject: [s], options: [])
        let array = daten.flatMap { String(data: $0, encoding: .utf8) } ?? "[\"\"]"
        return String(array.dropFirst().dropLast())
    }

    /// Wert als JavaScript-Ausdruck (JSON); nil wird zu null
    static func jsWert(_ wert: Any?) -> String {
        guard let wert else { return "null" }
        if let s = wert as? String { return jsString(s) }
        if JSONSerialization.isValidJSONObject(wert),
           let daten = try? JSONSerialization.data(withJSONObject: wert, options: []),
           let text = String(data: daten, encoding: .utf8) {
            return text
        }
        return "null"
    }
}
