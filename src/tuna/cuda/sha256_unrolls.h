#ifndef SHA256_UNROLLS_H
#define SHA256_UNROLLS_H

#define SHA256_COMPRESS_8X 								\
	for (i = 0; i < 64; i+=8) {							\
		t1 = h;											\
		t1 = t1 + EP1(e);								\
		t1 = t1 + CH(e,f,g);							\
		t1 = t1 + k[i];									\
		t1 = t1 + m[i];									\
		t2 = EP0(a);									\
		t2 = t2 + MAJ(a,b,c);							\
		h = g;											\
		g = f;											\
		f = e;											\
		e = d + t1;										\
		d = c;											\
		c = b;											\
		b = a;											\
		a = t1 + t2;									\
														\
		t1 = h;											\
		t1 = t1 + EP1(e);								\
		t1 = t1 + CH(e,f,g);							\
		t1 = t1 + k[i+1];								\
		t1 = t1 + m[i+1];								\
		t2 = EP0(a);									\
		t2 = t2 + MAJ(a,b,c);							\
		h = g;											\
		g = f;											\
		f = e;											\
		e = d + t1;										\
		d = c;											\
		c = b;											\
		b = a;											\
		a = t1 + t2;									\
														\
		t1 = h;											\
		t1 = t1 + EP1(e);								\
		t1 = t1 + CH(e,f,g);							\
		t1 = t1 + k[i+2];								\
		t1 = t1 + m[i+2];								\
		t2 = EP0(a);									\
		t2 = t2 + MAJ(a,b,c);							\
		h = g;											\
		g = f;											\
		f = e;											\
		e = d + t1;										\
		d = c;											\
		c = b;											\
		b = a;											\
		a = t1 + t2;									\
														\
		t1 = h;											\
		t1 = t1 + EP1(e);								\
		t1 = t1 + CH(e,f,g);							\
		t1 = t1 + k[i+3];								\
		t1 = t1 + m[i+3];								\
		t2 = EP0(a);									\
		t2 = t2 + MAJ(a,b,c);							\
		h = g;											\
		g = f;											\
		f = e;											\
		e = d + t1;										\
		d = c;											\
		c = b;											\
		b = a;											\
		a = t1 + t2;									\
														\
		t1 = h;											\
		t1 = t1 + EP1(e);								\
		t1 = t1 + CH(e,f,g);							\
		t1 = t1 + k[i+4];								\
		t1 = t1 + m[i+4];								\
		t2 = EP0(a);									\
		t2 = t2 + MAJ(a,b,c);							\
		h = g;											\
		g = f;											\
		f = e;											\
		e = d + t1;										\
		d = c;											\
		c = b;											\
		b = a;											\
		a = t1 + t2;									\
														\
		t1 = h;											\
		t1 = t1 + EP1(e);								\
		t1 = t1 + CH(e,f,g);							\
		t1 = t1 + k[i+5];								\
		t1 = t1 + m[i+5];								\
		t2 = EP0(a);									\
		t2 = t2 + MAJ(a,b,c);							\
		h = g;											\
		g = f;											\
		f = e;											\
		e = d + t1;										\
		d = c;											\
		c = b;											\
		b = a;											\
		a = t1 + t2;									\
														\
		t1 = h;											\
		t1 = t1 + EP1(e);								\
		t1 = t1 + CH(e,f,g);							\
		t1 = t1 + k[i+6];								\
		t1 = t1 + m[i+6];								\
		t2 = EP0(a);									\
		t2 = t2 + MAJ(a,b,c);							\
		h = g;											\
		g = f;											\
		f = e;											\
		e = d + t1;										\
		d = c;											\
		c = b;											\
		b = a;											\
		a = t1 + t2;									\
														\
		t1 = h;											\
		t1 = t1 + EP1(e);								\
		t1 = t1 + CH(e,f,g);							\
		t1 = t1 + k[i+7];								\
		t1 = t1 + m[i+7];								\
		t2 = EP0(a);									\
		t2 = t2 + MAJ(a,b,c);							\
		h = g;											\
		g = f;											\
		f = e;											\
		e = d + t1;										\
		d = c;											\
		c = b;											\
		b = a;											\
		a = t1 + t2;									\
	}

#define SHA256_COMPRESS_4X 								\
	for (i = 0; i < 64; i+=4) {							\
		t1 = h + EP1(e) + CH(e,f,g) + k[i] + m[i];		\
		t2 = EP0(a) + MAJ(a,b,c);						\
		h = g;											\
		g = f;											\
		f = e;											\
		e = d + t1;										\
		d = c;											\
		c = b;											\
		b = a;											\
		a = t1 + t2;									\
														\
		t1 = h + EP1(e) + CH(e,f,g) + k[i+1] + m[i+1];	\
		t2 = EP0(a) + MAJ(a,b,c);						\
		h = g;											\
		g = f;											\
		f = e;											\
		e = d + t1;										\
		d = c;											\
		c = b;											\
		b = a;											\
		a = t1 + t2;									\
														\
		t1 = h + EP1(e) + CH(e,f,g) + k[i+2] + m[i+2];	\
		t2 = EP0(a) + MAJ(a,b,c);						\
		h = g;											\
		g = f;											\
		f = e;											\
		e = d + t1;										\
		d = c;											\
		c = b;											\
		b = a;											\
		a = t1 + t2;									\
														\
		t1 = h + EP1(e) + CH(e,f,g) + k[i+3] + m[i+3];	\
		t2 = EP0(a) + MAJ(a,b,c);						\
		h = g;											\
		g = f;											\
		f = e;											\
		e = d + t1;										\
		d = c;											\
		c = b;											\
		b = a;											\
		a = t1 + t2;									\
	}

#define SHA256_COMPRESS_2X 								\
	for (i = 0; i < 64; i+=2) {							\
		t1 = h + EP1(e) + CH(e,f,g) + k[i] + m[i];		\
		t2 = EP0(a) + MAJ(a,b,c);						\
		h = g;											\
		g = f;											\
		f = e;											\
		e = d + t1;										\
		d = c;											\
		c = b;											\
		b = a;											\
		a = t1 + t2;									\
														\
		t1 = h + EP1(e) + CH(e,f,g) + k[i+1] + m[i+1];	\
		t2 = EP0(a) + MAJ(a,b,c);						\
		h = g;											\
		g = f;											\
		f = e;											\
		e = d + t1;										\
		d = c;											\
		c = b;											\
		b = a;											\
		a = t1 + t2;									\
}

	#define SHA256_COMPRESS_1X							\
	for (i = 0; i < 64; i++) {							\
		t1 = h + EP1(e) + CH(e,f,g) + k[i] + m[i];		\
		t2 = EP0(a) + MAJ(a,b,c);						\
		h = g;											\
		g = f;											\
		f = e;											\
		e = d + t1;										\
		d = c;											\
		c = b;											\
		b = a;											\
		a = t1 + t2;									\
	}

#endif