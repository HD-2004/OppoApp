# AI Interview Voice-Only Design

## Goal

Move the candidate AI interview screen from a typed chat experience to a speech-only turn-based interview. The candidate should hear each AI question, answer by microphone, and never see or type transcript text in the interview UI.

## Scope

- Keep the existing shared AI interview API: `startInterview` and `respondInterview`.
- Use device speech recognition to capture the candidate answer as hidden text.
- Use device text-to-speech to read each AI question aloud.
- Remove the visible chat message list, text input, and send button from the interview screen.
- Keep the existing application update behavior after a passing interview report.

## Out Of Scope

- No realtime streaming speech-to-speech model.
- No new backend audio transcription service.
- No audio upload or S3 audio storage flow.
- No change to the shared serverless contract.

## Data Flow

1. App starts interview through `startInterview`.
2. App stores `sessionId` and the current AI question internally.
3. App reads the AI question aloud with local TTS.
4. Candidate taps the microphone and speaks.
5. App captures speech recognition result as hidden transcript.
6. App sends the hidden transcript to `respondInterview`.
7. If there is another question, app reads it aloud and repeats.
8. If the interview is finished, app shows the existing result sheet and updates the existing application if the report passes.

## UI

The screen becomes a voice console: status text, AI avatar, listen/speak states, replay button, and a large microphone button. It does not render a transcript, text bubbles, or a text input field.

## Error Handling

If speech recognition or microphone permission is unavailable, show a concise error and allow retry. If TTS fails, keep the question internally and let the candidate replay after the engine is available.

## Testing

Add a regression test that verifies the AI interview screen imports speech/TTS support and no longer exposes `TextField`, `TextEditingController`, chat bubbles, or the old typed-answer hint.
