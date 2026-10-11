"""AI provider interface. v001 runs AI_DISABLED: pass-through, never invents data."""


class AIProvider:
    name = 'disabled'

    def enrich(self, item):
        return {
            'ai_mode': 'AI_DISABLED',
            'ai_summary': None,
            'ai_model': None,
            'ai_note': 'Attach a provider (local LLM / OpenAI / Gemini) to enable. See docs/AI.md.',
        }


class DisabledProvider(AIProvider):
    pass


def get_provider(config):
    mode = ((config or {}).get('ai') or {}).get('mode', 'AI_DISABLED')
    if mode == 'AI_DISABLED':
        return DisabledProvider()
    raise ValueError('AI mode %r not configured (no credentials in v001)' % (mode,))
