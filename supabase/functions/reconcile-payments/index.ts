import { handleReconcile } from '../_shared/backend.ts';
Deno.serve((request: Request) => handleReconcile(request, {env:(name: string) => Deno.env.get(name),fetch}));
