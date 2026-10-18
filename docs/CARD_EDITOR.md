# Card editing and free wallet

Full name, card name and job title use manual entry. The pitch has one combined
microphone/AI control inside the field. Speech is organised in a draft dialog;
the user reviews and applies it. Undo expires after three seconds.

Skills have separate inputs: up to 3,000 characters of experience for AI
extraction, or up to 1,000 characters of comma-separated manual tags. Individual
tags stay within 50 characters, with up to 12 tags per card. Suggested skills need
confirmation. Social profiles accept usernames; website entries accept addresses.

The free allowance is five owned cards. Received contacts do not consume slots.
Local creation and atomic cloud writes enforce the limit. Existing cards remain
editable; deleting one frees a slot. Existing wallets above the limit are
preserved and cannot add more until below five. Empty slots are placeholders,
not stored cards. Primary selection remains an explicit user choice.

The configured language model is Cloudflare Workers AI Llama 3.2 3B Instruct.
Phone/browser speech recognition provides transcription. An OpenAI provider has
not been configured or enabled.

About Me stores a private, account-scoped source profile with first/last name,
phone, up to five contact emails, social handles, and optional work details.
New users complete it before their first card. Creating a card copies the source
values; the email picker can select another saved address. Card edits are
independent of the source profile. Profiles sync across devices with version
checks and offline retry, and are removed by account deletion.

On small screens, the wizard footer hides while the keyboard is open. Manual
skill tags scroll into view with their Add action; Done adds valid tags and
closes the keyboard.
