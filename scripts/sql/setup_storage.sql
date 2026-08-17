INSERT INTO storage.buckets (id, name, public) VALUES ('institutions_logos', 'institutions_logos', true) ON CONFLICT (id) DO NOTHING;

CREATE POLICY "Public Access" ON storage.objects FOR SELECT USING (bucket_id = 'institutions_logos');

CREATE POLICY "Admin Upload" ON storage.objects FOR INSERT TO authenticated WITH CHECK (bucket_id = 'institutions_logos' AND (storage.foldername(name))[1] = (SELECT institution_id::text FROM public.profiles WHERE id = auth.uid() AND role = 'sudo' LIMIT 1));

CREATE POLICY "Admin Update" ON storage.objects FOR UPDATE TO authenticated USING (bucket_id = 'institutions_logos' AND (storage.foldername(name))[1] = (SELECT institution_id::text FROM public.profiles WHERE id = auth.uid() AND role = 'sudo' LIMIT 1));

CREATE POLICY "Admin Delete" ON storage.objects FOR DELETE TO authenticated USING (bucket_id = 'institutions_logos' AND (storage.foldername(name))[1] = (SELECT institution_id::text FROM public.profiles WHERE id = auth.uid() AND role = 'sudo' LIMIT 1));
