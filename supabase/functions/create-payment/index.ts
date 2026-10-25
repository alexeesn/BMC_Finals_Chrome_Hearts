import { handleCreate } from '../_shared/backend.ts';
Deno.serve((request: Request) => handleCreate(request, {env:(name: string) => Deno.env.get(name),fetch}));
