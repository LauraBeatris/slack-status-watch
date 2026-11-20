# Emails

The source of the emails Resend sends. They live in Resend as published templates and
are sent by the **Install link** automation, not from this repo. Edit them here, then
paste the HTML into the template in Resend and publish it, so the two stay the same.

| File | Template alias | Sent |
|---|---|---|
| `install-link.html` | `install-link` | As soon as someone asks for the link on `/installed` |
| `install-reminder.html` | `install-reminder` | One day later. The last email the automation sends |

The automation starts on the `install.link_requested` event, which `api/email-link.ts`
sends with the address someone typed. `{{{RESEND_UNSUBSCRIBE_URL}}}` is filled in by Resend.
