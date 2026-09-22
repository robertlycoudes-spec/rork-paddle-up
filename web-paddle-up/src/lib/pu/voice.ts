/**
 * Live audio coaching via the Web Speech API. One short cue, spoken between
 * reps — never a stream of commentary.
 */

export function speakCue(cue: string): void {
  if (typeof window === "undefined" || !("speechSynthesis" in window)) return;
  try {
    const utterance = new SpeechSynthesisUtterance(cue.toLowerCase());
    utterance.rate = 1.05;
    utterance.pitch = 1;
    utterance.volume = 0.9;
    window.speechSynthesis.cancel();
    window.speechSynthesis.speak(utterance);
  } catch {
    // Speech synthesis is unavailable — the on-screen cue still shows.
  }
}

export function stopSpeaking(): void {
  if (typeof window === "undefined" || !("speechSynthesis" in window)) return;
  try {
    window.speechSynthesis.cancel();
  } catch {
    // Nothing to cancel.
  }
}
