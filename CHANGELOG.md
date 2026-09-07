## 0.5.0

- Separate live-session chat errors from metadata refresh errors while keeping
  the backwards-compatible combined error stream.
- Expose author name, avatar variants, and timestamp on gifted-membership
  events so consumers can render them without reparsing raw payloads.

## 0.4.0

- Add typed deletion, banner, ticker, notice, poll, tooltip, and gifted
  membership events while preserving unknown actions losslessly.
- Expose read-only button and menu commands on messages and events.
- Preserve the complete `get_live_chat` response on every parsed batch and
  tolerate malformed or future list entries.
- Add accumulated metadata snapshots for sparse `updated_metadata` responses.
- Add strict public YouTube identifier/URL parsing and configurable locale.
- Add `YoutubeLiveSession` so chat and metadata share one live-page resolution.
- Expand deterministic tests and documentation for privacy, lifecycle, images,
  errors, raw data, and both supported endpoints.

## 0.3.0

- Model the complete anonymous `updated_metadata` response, including
  viewership, title, date, description, response context, continuation timing,
  entity mutations, and every known like-count field.
- Add one-shot metadata requests and serialized metadata polling that follows
  YouTube's continuation token and server-requested interval.
- Preserve complete raw metadata payloads for unknown and future fields.
- Add deterministic metadata model, transport, lifecycle, and recovery tests,
  plus a live metadata inspector.

## 0.2.0

- Add injectable HTTP transport, explicit timeouts, and typed request errors.
- Serialize polling, follow server timing, deduplicate message IDs, and close
  owned resources safely.
- Normalize YouTube media URLs and expose every image variant and dimension.
- Preserve multiple author badges, custom emoji variants, message kinds, and
  membership text.
- Expose secondary and unknown live-chat events plus raw renderer payloads.
- Add deterministic transport/parser tests and an anonymized live inspector.

## 0.1.0

- Initial anonymous YouTube live-chat client.
