import { handleWebhook } from '../_shared/backend.ts';
Deno.serve((request: Request) => handleWebhook(request, {env:(name: string) => Deno.env.get(name),fetch}));
