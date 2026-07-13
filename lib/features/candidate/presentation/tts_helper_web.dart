// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter, avoid_print
import 'dart:js' as js;


bool get isSupportedPlatform => true;

bool get isSpeakingPlatform {
  try {
    return js.context['isSpeaking'] == true;
  } catch (_) {
    return false;
  }
}

void speakPlatform(String text, {Function()? onStart, Function()? onEnd}) {
  try {
    if (onStart != null) {
      js.context['__onSpeechStart'] = onStart;
    }
    if (onEnd != null) {
      js.context['__onSpeechEnd'] = onEnd;
    }

    js.context.callMethod('eval', ["""
      window.__speakVietnamese = function(txt) {
        if (!window.speechSynthesis) return;
        window.speechSynthesis.cancel();
        
        var cleanText = txt.replace(/[\\uE000-\\uF8FF]|\\uD83C[\\uDC00-\\uDFFF]|\\uD83D[\\uDC00-\\uDFFF]|[\\u2011-\\u26FF]|\\uD83E[\\uDD10-\\uDDFF]/g, '').trim();
        if (!cleanText) return;

        var utterance = new SpeechSynthesisUtterance(cleanText);
        utterance.lang = 'vi-VN';
        utterance.rate = 1.0;
        utterance.pitch = 1.0;

        var voices = window.speechSynthesis.getVoices();
        var viVoice = voices.find(function(v) {
          return v.lang.indexOf('vi-VN') !== -1 || v.lang === 'vi';
        });
        if (viVoice) {
          utterance.voice = viVoice;
        }
        
        utterance.onstart = function() {
          window.isSpeaking = true;
          if (window.__onSpeechStart) window.__onSpeechStart();
        };
        utterance.onend = function() {
          window.isSpeaking = false;
          if (window.__onSpeechEnd) window.__onSpeechEnd();
        };
        utterance.onerror = function() {
          window.isSpeaking = false;
          if (window.__onSpeechEnd) window.__onSpeechEnd();
        };

        setTimeout(function() {
          window.speechSynthesis.speak(utterance);
        }, 100);
      };
    """]);
    
    js.context.callMethod('__speakVietnamese', [text]);
  } catch (e) {
    print('Error in web speakPlatform: \$e');
  }
}

void stopPlatform() {
  try {
    js.context.callMethod('eval', ["""
      (function() {
        if (window.speechSynthesis) {
          window.speechSynthesis.cancel();
        }
        window.isSpeaking = false;
        if (window.__onSpeechEnd) window.__onSpeechEnd();
      })
    """])?.call([]);
  } catch (_) {}
}
