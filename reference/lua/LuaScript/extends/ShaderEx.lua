
local ShaderEx = {}

ShaderEx.DalBlur = {
    frag = [[
        #ifdef GL_ES
        precision highp float;
        #endif
        varying vec4        v_fragmentColor;
        varying vec2        v_texCoord;
        uniform sampler2D   CC_Texture0;

        vec2 resolution = vec2(1.0, 1.0);
        uniform float blurRadius;// = 0.01;
        uniform float sampleNum;// = 2.5;

        void main(void)
        {
        vec3 col = vec3(0.0);
        //vec2 unit = 1.0 / resolution.xy;
        vec2 unit = resolution;

        float r = blurRadius;
        float sampleStep = r / sampleNum;

        float count = 0.0;

        for(float x = -r; x < r; x += sampleStep)
        {
        for(float y = -r; y < r; y += sampleStep)
        {
        float weight = (r - abs(x)) * (r - abs(y));
        col += texture2D(CC_Texture0, v_texCoord + vec2(x * unit.x, y * unit.y)).rgb * weight;
        count += weight;
        }
        }

        gl_FragColor = vec4(col / count, 1.0) * v_fragmentColor;
        }
        ]]
}

ShaderEx.DalShadow = {
    frag = [[
        #ifdef GL_ES
        precision highp float;
        #endif
        varying vec4        v_fragmentColor;
        varying vec2        v_texCoord;
        uniform sampler2D   CC_Texture0;
        void main(void)
        {
            vec4 textureColor = texture2D(CC_Texture0, v_texCoord);
            textureColor *= texture2D(CC_Texture1, v_texCoord).r;
            gl_FragColor = vec4(textureColor.a) * v_fragmentColor;
        }
    ]]
}

ShaderEx.Deformation = {
    frag = [[
        #ifdef GL_ES
        precision highp float;
        precision highp int;
        #endif

        uniform float lD;
        uniform float rD;
        uniform float lT;
        uniform float rT;

        varying vec4        v_fragmentColor;
        varying vec2        v_texCoord;
        uniform sampler2D   CC_Texture0;

        void main(void)
        {
            float dDx = lD - rD;
            float dTx = lT - rT;

            float x = v_texCoord.x;

            // 修复：防止分母为 0
            float denominator = 1.0 + dDx * x - lD + dTx * x - lT;
            denominator = abs(denominator) < 0.0001 ? 0.0001 : denominator;

            float y = (v_texCoord.y + dDx * x - lD) / denominator;

            // 修复：浮点数比较
            if(y < 0.0 || y > 1.0)
            {
                // 修复：浮点字面量
                gl_FragColor = vec4(0.0, 0.0, 0.0, 0.0);
            }
            else
            {
                vec4 textureColor = texture2D(CC_Texture0, vec2(x, y));
                gl_FragColor = v_fragmentColor * textureColor;
            }
        }
    ]]
}

ShaderEx.DalOpaque = {
    frag = [[
            #ifdef GL_ES
            precision highp float;
            precision highp int;  // 修复：补全精度
            #endif

            varying vec4        v_fragmentColor;
            varying vec2        v_texCoord;
            uniform sampler2D   CC_Texture0;
            uniform sampler2D   CC_Texture1;  // 修复：补声明
            uniform float tbx;
            uniform float bbx;
            uniform float distance;

            void main(void)
            {
                vec4 textureColor = texture2D(CC_Texture0, v_texCoord);
                textureColor *= texture2D(CC_Texture1, v_texCoord).r;

                vec4 newFragmentColor = v_fragmentColor;

                // 修复：防止分母为 0
                float deno = tbx - bbx;
                deno = abs(deno) < 0.0001 ? 0.0001 : deno;

                float k = 1.0 / deno;
                float b = 1.0 - tbx * k;
                float x = (v_texCoord.y - b) / k;

                if (v_texCoord.x > x)
                {
                    float d = 1.0 - x + distance;
                    d = abs(d) < 0.0001 ? 0.0001 : d;

                    float a = 1.0 - (v_texCoord.x - x) / d;
                    newFragmentColor.a = max(a, 0.0);  // 修复：浮点数比较
                }

                gl_FragColor = newFragmentColor * textureColor;
            }
        ]]
}


ShaderEx.DalMotionblur = {
    frag = [[
            #ifdef GL_ES
            precision lowp float;
            #endif

            #ifdef GL_ES
            // 修复：补充完整精度（float + int），解决所有精度警告
            precision mediump float;
            precision mediump int;
            #endif

            varying vec4 v_fragmentColor;
            varying vec2 v_texCoord;
            uniform vec2 v_center;
            uniform float f_ins;
            // 修复1：移除错误的 mediump 位置
            uniform float f_mlen;
            uniform int  flagBlur;

            void blur()
            {
                if (flagBlur == 1) {
                    vec2 os = v_center - v_texCoord;
                    // 修复：浮点数字面量规范 0.1 → 无问题，保留
                    float dis = max(sqrt(os.x * os.x + os.y * os.y), f_ins * 0.1);
                    float num = floor(dis * f_mlen) + 1.0;
                    float rate = 1.0 / num;
                    vec2 st = vec2(f_ins * os.x / dis, f_ins * os.y / dis);
                    vec4 sc = texture2D(CC_Texture0, v_texCoord);
                    vec4 c = vec4(0.0, 0.0, 0.0, 0.0);

                    os = v_texCoord;
                    // 修复2：移除循环变量的 mediump，字面量改为 1.0
                    for (float i = 1.0; i < num; i += 1.0)
                    {
                        os += st;
                        c += texture2D(CC_Texture0, os) * rate;
                    }

                    gl_FragColor.rgb = c.rgb + sc.rgb * rate;
                    gl_FragColor.a = sc.a;
                    return ;
                }

                gl_FragColor = texture2D(CC_Texture0, v_texCoord);
            }

            void main()
            {
                blur();
            }
        ]]
}

--气浪效果
ShaderEx.DalBlast = {

    frag = [[
        #ifdef GL_ES
        precision highp float;
        #endif

        varying vec4 v_fragmentColor;
        varying vec2 v_texCoord;

        uniform sampler2D   maskTex;
        uniform sampler2D   noiseTex;
        uniform int   flag;
        uniform vec2 TextureSize;

        const vec3 GlowColor = vec3(1.0, 1.0, 1.0);
        uniform float GlowRange;
        const float GlowExpand = 15.0;

        const float HeatForce = 0.01;

        vec4 highlightMask()
        {
            float R = 0.0, G = 0.0, B = 0.0, A = 0.0;
            float samplerPre = GlowRange;
            float radiusX = TextureSize.x;
            float radiusY = TextureSize.y;
            float glowAlpha = 0.0;
            float count = 0.0;
            for( float i = -GlowRange ; i <= GlowRange ; i += samplerPre )
            {
                for( float j = -GlowRange ; j <= GlowRange ; j += samplerPre )
                {
                    vec2 samplerTexCoord = vec2( v_texCoord.x + j * radiusX , v_texCoord.y + i * radiusY );
                    if( samplerTexCoord.x < 0.0 || samplerTexCoord.x > 1.0 || samplerTexCoord.y < 0.0 || samplerTexCoord.y > 1.0 )
                    {
                        glowAlpha +=0.0;
                    }
                    else
                    {
                        glowAlpha += texture2D( maskTex, samplerTexCoord ).a;
                        count +=1.0;
                    }
                }
            }
            glowAlpha /= count;
            R = GlowColor.r;
            G = GlowColor.g;
            B = GlowColor.b;
            A = glowAlpha * GlowExpand;

            return vec4(R * A, G * A, B * A, A);
        }


        vec4 calcTex(vec2 uv) {
            if (flag == 1) {
                vec4 mtex = highlightMask();
                vec4 oldmtex = texture2D(maskTex, uv);
                float mval = mtex.a;

                vec4 ntex = texture2D(noiseTex, uv);

                uv.x += ntex.r * HeatForce * mval;
                uv.y += ntex.g * HeatForce * mval;

                vec4 outTex = texture2D(CC_Texture0, uv);
                vec4 tex = outTex * (1.0 - oldmtex.a) + oldmtex;
                return tex;
            }

            vec4 oldmtex = texture2D(maskTex, uv);
            vec4 outTex = texture2D(CC_Texture0, uv);
            vec4 tex = outTex * (1.0 - oldmtex.a) + oldmtex;
            return tex;
        }

        void main()
        {
            vec4 tex = calcTex(v_texCoord);
            gl_FragColor = tex;
        }
    ]],

    vert = [[
                attribute vec4 a_position;
                attribute vec2 a_texCoord;
                attribute vec4 a_color;

                #ifdef GL_ES
                varying lowp vec4 v_fragmentColor;
                varying mediump vec2 v_texCoord;
                #else
                varying vec4 v_fragmentColor;
                varying vec2 v_texCoord;
                #endif

                void main()
                {
                    gl_Position = CC_MVPMatrix * a_position;
                    v_fragmentColor = a_color;
                    v_texCoord = a_texCoord;
                }
            ]]

}

ShaderEx.DalFWhite = {

    frag = [[
        #ifdef GL_ES
        precision mediump float;
        #endif

        varying vec4 v_fragmentColor;
        varying vec2 v_texCoord;
        uniform float speed;
        uniform vec3 u_color;

        vec4 calcTex(vec2 uv) {
            vec4 tex = texture2D(CC_Texture0, uv);
            float a = tex.a;
            return vec4(u_color * a, a) * v_fragmentColor;
        }

        void main()
        {
            vec4 tex = calcTex(v_texCoord);
            gl_FragColor = tex;
        }
    ]],

    vert = [[
        attribute vec4 a_position;
        attribute vec2 a_texCoord;
        attribute vec4 a_color;

        #ifdef GL_ES
        varying lowp vec4 v_fragmentColor;
        varying mediump vec2 v_texCoord;
        #else
        varying vec4 v_fragmentColor;
        varying vec2 v_texCoord;
        #endif

        void main()
        {
            gl_Position = CC_MVPMatrix * a_position;
            v_fragmentColor = a_color;
            v_texCoord = a_texCoord;
        }
    ]]

}

ShaderEx.UIGray = {
    frag = [[
        #ifdef GL_ES
        precision mediump float;
        #endif
            varying vec4 v_fragmentColor;
            varying vec2 v_texCoord;
        void main(void)
        {
            vec4 c = texture2D(CC_Texture0, v_texCoord);
            gl_FragColor.xyz = vec3(0.4*c.r + 0.4*c.g +0.4*c.b);
            gl_FragColor.w = c.w;
        }
    ]],
    vert = [[       
        attribute vec4 a_position; 
        attribute vec2 a_texCoord;
        attribute vec4 a_color;                                                   
        #ifdef GL_ES
            varying lowp vec4 v_fragmentColor;
            varying mediump vec2 v_texCoord;
        #else                      
            varying vec4 v_fragmentColor;
            varying vec2 v_texCoord;
        #endif 
        void main()
        {
            gl_Position = CC_MVPMatrix * a_position;
            v_fragmentColor = a_color;
            v_texCoord = a_texCoord;
         }
    ]]
}

----------------------------------------------------------------------
for k, v in pairs(ShaderEx) do
    local shaderName = k
    local fContent  = v.frag
    local vContent = v.vert
    if me.ShaderCache:getGLProgram(shaderName) then return end
    TFShaderManager:addShaderWithContent(fContent, vContent, shaderName)
end
