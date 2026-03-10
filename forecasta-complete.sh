#!/bin/bash
# ============================================================================
# FORECASTA - Complete Global Investment & Trade Intelligence Platform
# Unified Master Installation Script
# Version: 2.0.0 Production Ready
# ============================================================================

set -e

echo "╔═══════════════════════════════════════════════════════════════════════╗"
echo "║                                                                       ║"
echo "║   ░██████╗░░█████╗░██████╗░███████╗░█████╗░░██████╗░████████╗░█████╗░  ║"
echo "║   ██╔═══██╗██╔══██╗██╔══██╗██╔════╝██╔══██╗██╔════╝░╚══██╔══╝██╔══██╗  ║"
echo "║   ██║   ██║██║░░╚═╝██████╔╝█████╗░░██║░░╚═╝██║░░██╗░░░░██║░░░███████║  ║"
echo "║   ██║   ██║██║░░██╗██╔══██╗██╔══╝░░██║░░██╗██║░░╚██╗░░░██║░░░██╔══██║  ║"
echo "║   ╚██████╔╝╚█████╔╝██║░░██║███████╗╚█████╔╝╚██████╔╝░░░██║░░░██║░░██║  ║"
echo "║   ░╚═════╝░░╚════╝░╚═╝░░╚═╝╚══════╝░╚════╝░░╚═════╝░░░░╚═╝░░░╚═╝░░╚═╝  ║"
echo "║                                                                       ║"
echo "║              GLOBAL INVESTMENT & TRADE INTELLIGENCE                   ║"
echo "║                    Production Deployment Package                      ║"
echo "║                         Version 2.0.0                                 ║"
echo "╚═══════════════════════════════════════════════════════════════════════╝"
echo ""

# ============================================================================
# CONFIGURATION
# ============================================================================

PROJECT_NAME="forecasta"
PROJECT_DIR="$HOME/$PROJECT_NAME"

echo "📁 Creating project directory: $PROJECT_DIR"
mkdir -p $PROJECT_DIR
cd $PROJECT_DIR

# ============================================================================
# 1. PROJECT STRUCTURE
# ============================================================================

echo "📁 Creating project structure..."
mkdir -p {frontend,backend,infrastructure/docker,infrastructure/kubernetes,scripts,data}

# ============================================================================
# 2. BACKEND FILES
# ============================================================================

echo "📦 Generating backend files..."

# 2.1 requirements.txt
cat > backend/requirements.txt << 'EOF'
fastapi==0.104.1
uvicorn[standard]==0.24.0
sqlalchemy==2.0.23
alembic==1.12.1
asyncpg==0.29.0
geoalchemy2==0.14.3
redis==5.0.1
celery==5.3.4
httpx==0.25.1
pydantic==2.5.0
pydantic-settings==2.1.0
python-jose[cryptography]==3.3.0
passlib[bcrypt]==1.7.4
python-multipart==0.0.6
openai==1.3.0
elasticsearch==8.11.0
pandas==2.1.3
numpy==1.26.2
scikit-learn==1.3.2
prophet==1.1.5
sentry-sdk==1.38.0
prometheus-fastapi-instrumentator==6.1.0
python-dotenv==1.0.0
psycopg2-binary==2.9.9
EOF

# 2.2 Main application
mkdir -p backend/app
mkdir -p backend/app/{api,core,models,services,agents,tasks}
mkdir -p backend/app/api/v1

cat > backend/app/main.py << 'EOF'
"""
Forecasta - Global Investment & Trade Intelligence Platform
Production-Ready FastAPI Application
"""

from fastapi import FastAPI, Depends, HTTPException, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.middleware.trustedhost import TrustedHostMiddleware
from fastapi.responses import JSONResponse
from contextlib import asynccontextmanager
import logging
import sentry_sdk
from prometheus_fastapi_instrumentator import Instrumentator
from datetime import datetime
import uuid

from app.core.config import settings
from app.core.database import engine
from app.core.security import setup_security
from app.core.middleware import RequestLoggingMiddleware, RateLimitMiddleware
from app.api.v1 import api_router

# Initialize Sentry
if settings.SENTRY_DSN:
    sentry_sdk.init(
        dsn=settings.SENTRY_DSN,
        environment=settings.ENVIRONMENT,
        traces_sample_rate=0.1
    )

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

@asynccontextmanager
async def lifespan(app: FastAPI):
    """Lifespan manager for startup/shutdown events."""
    logger.info("🚀 Starting Forecasta platform...")
    yield
    logger.info("🛑 Shutting down Forecasta platform...")

# Initialize FastAPI
app = FastAPI(
    title="Forecasta API",
    version="2.0.0",
    description="Global Investment & Trade Intelligence Platform",
    docs_url="/api/docs" if settings.ENVIRONMENT != "production" else None,
    redoc_url="/api/redoc" if settings.ENVIRONMENT != "production" else None,
    lifespan=lifespan
)

# Security middleware
app.add_middleware(
    TrustedHostMiddleware,
    allowed_hosts=settings.ALLOWED_HOSTS
)

# CORS configuration
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.CORS_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Custom middleware
app.add_middleware(RequestLoggingMiddleware)
app.add_middleware(RateLimitMiddleware)

# Setup security headers
setup_security(app)

# Include API router
app.include_router(api_router, prefix="/api/v1")

# Health check endpoint
@app.get("/health")
async def health_check():
    return {
        "status": "healthy",
        "timestamp": datetime.utcnow().isoformat(),
        "version": "2.0.0",
        "environment": settings.ENVIRONMENT,
        "instance_id": str(uuid.uuid4())[:8]
    }

# Metrics endpoint
instrumentator = Instrumentator()
instrumentator.instrument(app).expose(app)

# Error handlers
@app.exception_handler(HTTPException)
async def http_exception_handler(request: Request, exc: HTTPException):
    return JSONResponse(
        status_code=exc.status_code,
        content={
            "error": exc.detail,
            "status_code": exc.status_code,
            "path": request.url.path
        }
    )

@app.exception_handler(Exception)
async def general_exception_handler(request: Request, exc: Exception):
    logger.error(f"Unhandled exception: {exc}", exc_info=True)
    return JSONResponse(
        status_code=500,
        content={
            "error": "Internal server error",
            "status_code": 500,
            "path": request.url.path
        }
    )
EOF

# 2.3 Configuration
cat > backend/app/core/config.py << 'EOF'
"""
Forecasta Configuration Module
"""

from pydantic_settings import BaseSettings
from typing import List, Optional
import secrets

class Settings(BaseSettings):
    # Environment
    ENVIRONMENT: str = "development"
    DEBUG: bool = False
    
    # Security
    SECRET_KEY: str = secrets.token_urlsafe(32)
    JWT_ALGORITHM: str = "HS256"
    JWT_EXPIRATION_MINUTES: int = 30
    REFRESH_TOKEN_EXPIRATION_DAYS: int = 7
    ALLOWED_HOSTS: List[str] = ["*"]
    CORS_ORIGINS: List[str] = [
        "http://localhost:3000",
        "https://forecasta.com",
        "https://www.forecasta.com"
    ]
    
    # Database
    POSTGRES_USER: str = "forecasta"
    POSTGRES_PASSWORD: str = "forecasta123"
    POSTGRES_HOST: str = "postgres"
    POSTGRES_PORT: str = "5432"
    POSTGRES_DB: str = "forecasta"
    
    @property
    def DATABASE_URL(self) -> str:
        return f"postgresql://{self.POSTGRES_USER}:{self.POSTGRES_PASSWORD}@{self.POSTGRES_HOST}:{self.POSTGRES_PORT}/{self.POSTGRES_DB}"
    
    # Redis
    REDIS_HOST: str = "redis"
    REDIS_PORT: int = 6379
    REDIS_PASSWORD: Optional[str] = None
    
    @property
    def REDIS_URL(self) -> str:
        if self.REDIS_PASSWORD:
            return f"redis://:{self.REDIS_PASSWORD}@{self.REDIS_HOST}:{self.REDIS_PORT}"
        return f"redis://{self.REDIS_HOST}:{self.REDIS_PORT}"
    
    # APIs
    OPENAI_API_KEY: str = ""
    MAPBOX_TOKEN: str = ""
    NEWS_API_KEY: str = ""
    
    # Rate limiting
    RATE_LIMIT_REQUESTS: int = 100
    RATE_LIMIT_PERIOD: int = 60
    
    # Cache
    CACHE_TTL: int = 300
    
    # Pagination
    DEFAULT_PAGE_SIZE: int = 20
    MAX_PAGE_SIZE: int = 100
    
    # Feature flags
    ENABLE_AI_AGENTS: bool = True
    ENABLE_REAL_TIME_UPDATES: bool = True
    ENABLE_BILINGUAL: bool = True
    
    class Config:
        env_file = ".env"
        case_sensitive = True

settings = Settings()
EOF

# 2.4 Database
cat > backend/app/core/database.py << 'EOF'
"""
Database configuration.
"""

from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession
from sqlalchemy.orm import sessionmaker, declarative_base
from app.core.config import settings

# Convert PostgreSQL URL to asyncpg format
db_url = settings.DATABASE_URL.replace("postgresql://", "postgresql+asyncpg://")

engine = create_async_engine(
    db_url,
    echo=settings.DEBUG,
    pool_size=20,
    max_overflow=10
)

AsyncSessionLocal = sessionmaker(
    engine,
    class_=AsyncSession,
    expire_on_commit=False
)

Base = declarative_base()

async def get_db():
    async with AsyncSessionLocal() as session:
        try:
            yield session
        finally:
            await session.close()
EOF

# 2.5 Security
cat > backend/app/core/security.py << 'EOF'
"""
Security utilities.
"""

from datetime import datetime, timedelta
from jose import JWTError, jwt
from passlib.context import CryptContext
from fastapi import HTTPException, Security
from fastapi.security import HTTPBearer
from app.core.config import settings

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")
security = HTTPBearer()

def verify_password(plain_password: str, hashed_password: str) -> bool:
    return pwd_context.verify(plain_password, hashed_password)

def get_password_hash(password: str) -> str:
    return pwd_context.hash(password)

def create_access_token(data: dict) -> str:
    to_encode = data.copy()
    expire = datetime.utcnow() + timedelta(minutes=settings.JWT_EXPIRATION_MINUTES)
    to_encode.update({"exp": expire})
    return jwt.encode(to_encode, settings.SECRET_KEY, algorithm=settings.JWT_ALGORITHM)

def setup_security(app):
    @app.middleware("http")
    async def add_security_headers(request, call_next):
        response = await call_next(request)
        response.headers["X-Content-Type-Options"] = "nosniff"
        response.headers["X-Frame-Options"] = "DENY"
        response.headers["X-XSS-Protection"] = "1; mode=block"
        response.headers["Strict-Transport-Security"] = "max-age=31536000; includeSubDomains"
        return response
EOF

# 2.6 Middleware
cat > backend/app/core/middleware.py << 'EOF'
"""
Custom middleware.
"""

import time
import logging
from fastapi import Request, HTTPException
from starlette.middleware.base import BaseHTTPMiddleware
from collections import defaultdict
from typing import Dict
import asyncio

logger = logging.getLogger(__name__)

class RequestLoggingMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request: Request, call_next):
        start_time = time.time()
        response = await call_next(request)
        process_time = time.time() - start_time
        logger.info(f"{request.method} {request.url.path} - {response.status_code} - {process_time:.3f}s")
        return response

class RateLimitMiddleware(BaseHTTPMiddleware):
    def __init__(self, app, requests_per_minute: int = 100):
        super().__init__(app)
        self.requests_per_minute = requests_per_minute
        self.requests: Dict[str, list] = defaultdict(list)
        self.lock = asyncio.Lock()
    
    async def dispatch(self, request: Request, call_next):
        client_ip = request.client.host
        async with self.lock:
            now = time.time()
            self.requests[client_ip] = [
                req_time for req_time in self.requests[client_ip]
                if now - req_time < 60
            ]
            if len(self.requests[client_ip]) >= self.requests_per_minute:
                raise HTTPException(status_code=429, detail="Rate limit exceeded")
            self.requests[client_ip].append(now)
        return await call_next(request)
EOF

# 2.7 API Router
cat > backend/app/api/v1/__init__.py << 'EOF'
from fastapi import APIRouter

api_router = APIRouter()

# Import routes
from . import signals

api_router.include_router(signals.router, prefix="/signals", tags=["Signals"])
EOF

# 2.8 Signals API
cat > backend/app/api/v1/signals.py << 'EOF'
from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func, desc
from typing import Optional
from datetime import datetime, timedelta

from app.core.database import get_db
from app.models import Signal, Company, Country

router = APIRouter()

@router.get("/")
async def get_signals(
    target_country_id: Optional[int] = Query(None),
    sector_id: Optional[int] = Query(None),
    min_confidence: float = Query(0.5),
    days_back: int = Query(30),
    limit: int = Query(50),
    offset: int = Query(0),
    db: AsyncSession = Depends(get_db)
):
    query = (
        select(
            Signal,
            Company.name_en.label("company_name"),
            Country.name_en.label("target_country_name")
        )
        .join(Company, Signal.company_id == Company.id)
        .join(Country, Signal.target_country_id == Country.id)
        .where(Signal.confidence_score >= min_confidence)
        .where(Signal.detection_date >= datetime.now() - timedelta(days=days_back))
    )
    
    if target_country_id:
        query = query.where(Signal.target_country_id == target_country_id)
    if sector_id:
        query = query.where(Signal.sector_id == sector_id)
    
    query = query.order_by(desc(Signal.detection_date)).offset(offset).limit(limit)
    result = await db.execute(query)
    signals = result.all()
    
    return {
        "data": [
            {
                "id": s.Signal.uuid,
                "company_name": s.company_name,
                "title": s.Signal.title_en,
                "target_country": s.target_country_name,
                "estimated_value_usd": s.Signal.estimated_value_usd,
                "confidence_score": s.Signal.confidence_score,
                "detection_date": s.Signal.detection_date
            }
            for s in signals
        ],
        "metadata": {
            "offset": offset,
            "limit": limit
        }
    }
EOF

# 2.9 Models
cat > backend/app/models.py << 'EOF'
from sqlalchemy import Column, Integer, String, Float, DateTime, Boolean, ForeignKey, Text, JSON
from sqlalchemy.dialects.postgresql import UUID
from geoalchemy2 import Geometry
from app.core.database import Base
import uuid
from datetime import datetime

class Country(Base):
    __tablename__ = 'countries'
    
    id = Column(Integer, primary_key=True)
    uuid = Column(UUID(as_uuid=True), default=uuid.uuid4, unique=True)
    iso2 = Column(String(2), unique=True, nullable=False)
    iso3 = Column(String(3), unique=True, nullable=False)
    name_en = Column(String(100), nullable=False)
    name_ar = Column(String(100))
    region = Column(String(50))
    latitude = Column(Float)
    longitude = Column(Float)
    created_at = Column(DateTime, default=datetime.utcnow)

class Company(Base):
    __tablename__ = 'companies'
    
    id = Column(Integer, primary_key=True)
    uuid = Column(UUID(as_uuid=True), default=uuid.uuid4, unique=True)
    name_en = Column(String(200), nullable=False)
    name_ar = Column(String(200))
    created_at = Column(DateTime, default=datetime.utcnow)

class Sector(Base):
    __tablename__ = 'sectors'
    
    id = Column(Integer, primary_key=True)
    uuid = Column(UUID(as_uuid=True), default=uuid.uuid4, unique=True)
    name_en = Column(String(100), nullable=False)
    name_ar = Column(String(100))
    code = Column(String(20), unique=True)
    created_at = Column(DateTime, default=datetime.utcnow)

class Signal(Base):
    __tablename__ = 'signals'
    
    id = Column(Integer, primary_key=True)
    uuid = Column(UUID(as_uuid=True), default=uuid.uuid4, unique=True, nullable=False)
    company_id = Column(Integer, ForeignKey('companies.id'), nullable=False)
    title_en = Column(String(300), nullable=False)
    title_ar = Column(String(300))
    signal_type = Column(String(50))
    target_country_id = Column(Integer, ForeignKey('countries.id'), nullable=False)
    sector_id = Column(Integer, ForeignKey('sectors.id'))
    estimated_value_usd = Column(Float)
    confidence_score = Column(Float, default=0.5)
    detection_date = Column(DateTime, default=datetime.utcnow)
    verification_status = Column(String(20), default='pending')
    source_url = Column(Text)
    created_at = Column(DateTime, default=datetime.utcnow)
EOF

# 2.10 Alembic setup
mkdir -p backend/alembic
mkdir -p backend/alembic/versions

cat > backend/alembic/env.py << 'EOF'
from logging.config import fileConfig
from sqlalchemy import engine_from_config
from sqlalchemy import pool
from alembic import context
import sys
from pathlib import Path

sys.path.append(str(Path(__file__).parent.parent))
from app.core.database import Base
from app import models

config = context.config
fileConfig(config.config_file_name)
target_metadata = Base.metadata

def run_migrations_offline():
    url = config.get_main_option("sqlalchemy.url")
    context.configure(url=url, target_metadata=target_metadata, literal_binds=True)
    with context.begin_transaction():
        context.run_migrations()

def run_migrations_online():
    connectable = engine_from_config(
        config.get_section(config.config_ini_section),
        prefix="sqlalchemy.",
        poolclass=pool.NullPool,
    )
    with connectable.connect() as connection:
        context.configure(connection=connection, target_metadata=target_metadata)
        with context.begin_transaction():
            context.run_migrations()

if context.is_offline_mode():
    run_migrations_offline()
else:
    run_migrations_online()
EOF

cat > backend/alembic/script.py.mako << 'EOF'
"""${message}

Revision ID: ${up_revision}
Revises: ${down_revision | comma,n}
Create Date: ${create_date}
"""
from alembic import op
import sqlalchemy as sa
${imports if imports else ""}

revision = ${repr(up_revision)}
down_revision = ${repr(down_revision)}
branch_labels = ${repr(branch_labels)}
depends_on = ${repr(depends_on)}

def upgrade():
    ${upgrades if upgrades else "pass"}

def downgrade():
    ${downgrades if downgrades else "pass"}
EOF

# ============================================================================
# 3. FRONTEND FILES
# ============================================================================

echo "🎨 Generating frontend files..."

# 3.1 package.json
cat > frontend/package.json << 'EOF'
{
  "name": "forecasta",
  "version": "2.0.0",
  "private": true,
  "scripts": {
    "dev": "next dev",
    "build": "next build",
    "start": "next start"
  },
  "dependencies": {
    "next": "14.0.3",
    "react": "18.2.0",
    "react-dom": "18.2.0",
    "typescript": "5.3.2",
    "@types/node": "20.10.0",
    "@types/react": "18.2.39",
    "@types/react-dom": "18.2.17",
    "tailwindcss": "3.3.6",
    "autoprefixer": "10.4.16",
    "postcss": "8.4.31",
    "framer-motion": "10.16.5",
    "axios": "1.6.2",
    "react-query": "3.39.3",
    "recharts": "2.10.3",
    "mapbox-gl": "3.1.2",
    "react-map-gl": "7.1.6",
    "lucide-react": "0.292.0",
    "date-fns": "2.30.0"
  }
}
EOF

# 3.2 next.config.js
cat > frontend/next.config.js << 'EOF'
/** @type {import('next').NextConfig} */
const nextConfig = {
  reactStrictMode: true,
  swcMinify: true,
  output: 'standalone',
  images: {
    domains: ['flagcdn.com'],
  },
  env: {
    NEXT_PUBLIC_API_URL: process.env.NEXT_PUBLIC_API_URL || 'http://localhost:8000',
    NEXT_PUBLIC_MAPBOX_TOKEN: process.env.NEXT_PUBLIC_MAPBOX_TOKEN,
  },
}

module.exports = nextConfig
EOF

# 3.3 tailwind.config.js
cat > frontend/tailwind.config.js << 'EOF'
/** @type {import('tailwindcss').Config} */
module.exports = {
  content: [
    './app/**/*.{js,ts,jsx,tsx,mdx}',
    './components/**/*.{js,ts,jsx,tsx,mdx}',
  ],
  theme: {
    extend: {
      colors: {
        'deep-navy': '#07111F',
        'deep-slate': '#0E1A2B',
        'graphite-blue': '#122338',
        'electric-blue': '#22D3EE',
        'royal-blue': '#3B82F6',
        'emerald': '#10B981',
        'amber': '#F59E0B',
        'crimson': '#EF4444',
        'signal-purple': '#8B5CF6',
        'cool-gray': '#AAB7C7',
      },
      fontFamily: {
        sans: ['Inter', 'sans-serif'],
        display: ['Space Grotesk', 'sans-serif'],
      },
    },
  },
  plugins: [],
}
EOF

# 3.4 postcss.config.js
cat > frontend/postcss.config.js << 'EOF'
module.exports = {
  plugins: {
    tailwindcss: {},
    autoprefixer: {},
  },
}
EOF

# 3.5 tsconfig.json
cat > frontend/tsconfig.json << 'EOF'
{
  "compilerOptions": {
    "target": "es5",
    "lib": ["dom", "dom.iterable", "esnext"],
    "allowJs": true,
    "skipLibCheck": true,
    "strict": true,
    "forceConsistentCasingInFileNames": true,
    "noEmit": true,
    "esModuleInterop": true,
    "module": "esnext",
    "moduleResolution": "node",
    "resolveJsonModule": true,
    "isolatedModules": true,
    "jsx": "preserve",
    "incremental": true,
    "plugins": [
      {
        "name": "next"
      }
    ],
    "paths": {
      "@/*": ["./*"]
    }
  },
  "include": ["next-env.d.ts", "**/*.ts", "**/*.tsx", ".next/types/**/*.ts"],
  "exclude": ["node_modules"]
}
EOF

# 3.6 App layout
mkdir -p frontend/app
mkdir -p frontend/components/ui
mkdir -p frontend/lib

cat > frontend/app/layout.tsx << 'EOF'
import type { Metadata } from 'next'
import { Inter, Space_Grotesk } from 'next/font/google'
import './globals.css'

const inter = Inter({ subsets: ['latin'], variable: '--font-inter' })
const spaceGrotesk = Space_Grotesk({ 
  subsets: ['latin'], 
  variable: '--font-space-grotesk' 
})

export const metadata: Metadata = {
  title: 'Forecasta - Global Investment Intelligence',
  description: 'Real-time global investment intelligence platform',
}

export default function RootLayout({
  children,
}: {
  children: React.ReactNode
}) {
  return (
    <html lang="en">
      <body className={`${inter.variable} ${spaceGrotesk.variable} font-sans bg-deep-navy text-white`}>
        {children}
      </body>
    </html>
  )
}
EOF

# 3.7 Global CSS
cat > frontend/app/globals.css << 'EOF'
@tailwind base;
@tailwind components;
@tailwind utilities;

@layer base {
  body {
    @apply antialiased;
  }
}

@layer utilities {
  .text-gradient {
    @apply bg-gradient-to-r from-electric-blue to-signal-purple bg-clip-text text-transparent;
  }
}

/* Custom scrollbar */
::-webkit-scrollbar {
  width: 8px;
  height: 8px;
}

::-webkit-scrollbar-track {
  @apply bg-deep-slate;
}

::-webkit-scrollbar-thumb {
  @apply bg-electric-blue/30 rounded-full hover:bg-electric-blue/50 transition-colors;
}
EOF

# 3.8 Homepage
cat > frontend/app/page.tsx << 'EOF'
'use client'

import { useEffect, useState } from 'react'
import { motion } from 'framer-motion'
import { TrendingUp, Globe, Award, Zap } from 'lucide-react'
import Link from 'next/link'

export default function HomePage() {
  const [stats, setStats] = useState({
    fdi: '$1.9T',
    trade: '$32.0T',
    ranking: 'Singapore',
    signals: '12,458'
  })

  return (
    <main className="min-h-screen">
      {/* Hero Section */}
      <section className="relative h-screen flex items-center justify-center overflow-hidden">
        <div className="absolute inset-0 bg-gradient-to-b from-electric-blue/5 to-transparent" />
        
        <div className="relative z-10 text-center max-w-5xl mx-auto px-4">
          <motion.h1 
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.8 }}
            className="text-5xl md:text-7xl font-bold mb-6 text-gradient"
          >
            Global Investment & Trade Intelligence
          </motion.h1>
          
          <motion.p 
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.8, delay: 0.2 }}
            className="text-xl text-cool-gray mb-10 max-w-3xl mx-auto"
          >
            Real-time signals, proprietary rankings, and AI-powered insights
          </motion.p>
          
          <motion.div 
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.8, delay: 0.4 }}
            className="flex gap-4 justify-center"
          >
            <Link
              href="/monitor"
              className="px-8 py-4 bg-electric-blue hover:bg-blue-600 text-white rounded-full font-semibold transition-all transform hover:scale-105"
            >
              Explore Platform
            </Link>
            <Link
              href="/ranking"
              className="px-8 py-4 bg-transparent border-2 border-electric-blue text-electric-blue hover:bg-electric-blue hover:text-white rounded-full font-semibold transition-all"
            >
              View Ranking
            </Link>
          </motion.div>
        </div>
      </section>

      {/* Stats Section */}
      <section className="py-12 bg-graphite-blue">
        <div className="max-w-7xl mx-auto px-4">
          <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
            {[
              { title: 'FDI Flows', value: stats.fdi, icon: TrendingUp },
              { title: 'Trade Volume', value: stats.trade, icon: Globe },
              { title: 'Top Ranked', value: stats.ranking, icon: Award },
              { title: 'Active Signals', value: stats.signals, icon: Zap },
            ].map((stat, i) => (
              <motion.div
                key={stat.title}
                initial={{ opacity: 0, y: 20 }}
                animate={{ opacity: 1, y: 0 }}
                transition={{ delay: 0.1 * i }}
                className="bg-deep-navy rounded-xl p-6 text-center"
              >
                <stat.icon className="w-8 h-8 mx-auto mb-3 text-electric-blue" />
                <div className="text-2xl font-bold text-white">{stat.value}</div>
                <div className="text-sm text-cool-gray">{stat.title}</div>
              </motion.div>
            ))}
          </div>
        </div>
      </section>
    </main>
  )
}
EOF

# 3.9 API Client
cat > frontend/lib/api.ts << 'EOF'
import axios from 'axios'

const api = axios.create({
  baseURL: process.env.NEXT_PUBLIC_API_URL || 'http://localhost:8000/api/v1',
  timeout: 10000,
})

export const getSignals = async (params?: any) => {
  const response = await api.get('/signals', { params })
  return response.data
}

export default api
EOF

# ============================================================================
# 4. DOCKER FILES
# ============================================================================

echo "🐳 Generating Docker files..."

# 4.1 Docker Compose
cat > infrastructure/docker/docker-compose.yml << 'EOF'
version: '3.8'

services:
  postgres:
    image: postgis/postgis:15-3.4
    container_name: forecasta-postgres
    environment:
      POSTGRES_DB: forecasta
      POSTGRES_USER: forecasta
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD:-forecasta123}
    volumes:
      - postgres_data:/var/lib/postgresql/data
    ports:
      - "5432:5432"
    networks:
      - forecasta_net
    restart: unless-stopped
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U forecasta"]
      interval: 10s
      timeout: 5s
      retries: 5

  redis:
    image: redis:7-alpine
    container_name: forecasta-redis
    command: redis-server --appendonly yes
    volumes:
      - redis_data:/data
    ports:
      - "6379:6379"
    networks:
      - forecasta_net
    restart: unless-stopped

  backend:
    build:
      context: ../../backend
      dockerfile: ../infrastructure/docker/Dockerfile.backend
    container_name: forecasta-backend
    environment:
      - ENVIRONMENT=production
      - DATABASE_URL=postgresql://forecasta:${POSTGRES_PASSWORD:-forecasta123}@postgres:5432/forecasta
      - REDIS_URL=redis://redis:6379
      - SECRET_KEY=${SECRET_KEY:-supersecretkey123}
    ports:
      - "8000:8000"
    depends_on:
      postgres:
        condition: service_healthy
      redis:
        condition: service_started
    networks:
      - forecasta_net
    restart: unless-stopped

  frontend:
    build:
      context: ../../frontend
      dockerfile: ../infrastructure/docker/Dockerfile.frontend
    container_name: forecasta-frontend
    environment:
      - NEXT_PUBLIC_API_URL=http://localhost:8000
      - NEXT_PUBLIC_MAPBOX_TOKEN=${MAPBOX_TOKEN:-}
    ports:
      - "3000:3000"
    depends_on:
      - backend
    networks:
      - forecasta_net
    restart: unless-stopped

  nginx:
    image: nginx:alpine
    container_name: forecasta-nginx
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf
    ports:
      - "80:80"
    depends_on:
      - frontend
      - backend
    networks:
      - forecasta_net
    restart: unless-stopped

volumes:
  postgres_data:
  redis_data:

networks:
  forecasta_net:
    driver: bridge
EOF

# 4.2 Backend Dockerfile
cat > infrastructure/docker/Dockerfile.backend << 'EOF'
FROM python:3.11-slim

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

WORKDIR /app

COPY backend/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY backend/ .

RUN adduser --disabled-password --gecos '' appuser && chown -R appuser:appuser /app
USER appuser

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
EOF

# 4.3 Frontend Dockerfile
cat > infrastructure/docker/Dockerfile.frontend << 'EOF'
FROM node:18-alpine AS builder

WORKDIR /app

COPY frontend/package*.json ./
RUN npm ci

COPY frontend/ .
RUN npm run build

FROM node:18-alpine AS runner

WORKDIR /app

ENV NODE_ENV production

COPY --from=builder /app/next.config.js ./
COPY --from=builder /app/public ./public
COPY --from=builder /app/.next/standalone ./
COPY --from=builder /app/.next/static ./.next/static

RUN addgroup --system --gid 1001 nodejs
RUN adduser --system --uid 1001 nextjs
USER nextjs

EXPOSE 3000

CMD ["node", "server.js"]
EOF

# 4.4 Nginx config
cat > infrastructure/docker/nginx.conf << 'EOF'
events {
    worker_connections 1024;
}

http {
    upstream frontend {
        server frontend:3000;
    }

    upstream backend {
        server backend:8000;
    }

    server {
        listen 80;
        server_name _;

        location / {
            proxy_pass http://frontend;
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection 'upgrade';
            proxy_set_header Host $host;
            proxy_cache_bypass $http_upgrade;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        }

        location /api/ {
            proxy_pass http://backend/api/;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
        }
    }
}
EOF

# ============================================================================
# 5. SCRIPTS
# ============================================================================

echo "📜 Generating utility scripts..."

# 5.1 Seed data script
cat > scripts/seed_data.py << 'EOF'
#!/usr/bin/env python3
"""
Initial data seeding script.
"""

import asyncio
import asyncpg
import random
from datetime import datetime, timedelta

async def seed_countries(conn):
    countries = [
        ('AE', 'ARE', 'United Arab Emirates', 25.2048, 55.2708),
        ('SA', 'SAU', 'Saudi Arabia', 23.8859, 45.0792),
        ('US', 'USA', 'United States', 37.0902, -95.7129),
        ('SG', 'SGP', 'Singapore', 1.3521, 103.8198),
    ]
    
    for iso2, iso3, name, lat, lng in countries:
        await conn.execute("""
            INSERT INTO countries (iso2, iso3, name_en, latitude, longitude, created_at)
            VALUES ($1, $2, $3, $4, $5, NOW())
            ON CONFLICT (iso2) DO NOTHING
        """, iso2, iso3, name, lat, lng)
    
    print(f"✅ Seeded {len(countries)} countries")

async def seed_sectors(conn):
    sectors = [
        ('Technology', 'TECH'),
        ('Energy', 'ENERGY'),
        ('Manufacturing', 'MFG'),
    ]
    
    for name, code in sectors:
        await conn.execute("""
            INSERT INTO sectors (name_en, code, created_at)
            VALUES ($1, $2, NOW())
            ON CONFLICT (code) DO NOTHING
        """, name, code)
    
    print(f"✅ Seeded {len(sectors)} sectors")

async def seed_companies(conn):
    companies = ['Tesla', 'Microsoft', 'Amazon', 'Google']
    for company in companies:
        await conn.execute("""
            INSERT INTO companies (name_en, created_at)
            VALUES ($1, NOW())
            ON CONFLICT DO NOTHING
        """, company)
    
    print(f"✅ Seeded {len(companies)} companies")

async def seed_signals(conn):
    companies = await conn.fetch("SELECT id FROM companies")
    sectors = await conn.fetch("SELECT id FROM sectors")
    countries = await conn.fetch("SELECT id FROM countries")
    
    for i in range(20):
        company = random.choice(companies)['id']
        sector = random.choice(sectors)['id']
        country = random.choice(countries)['id']
        confidence = random.uniform(0.6, 0.95)
        value = random.uniform(100, 5000) * 1_000_000
        days_ago = random.randint(0, 30)
        
        await conn.execute("""
            INSERT INTO signals (
                company_id, title_en, signal_type, target_country_id,
                sector_id, estimated_value_usd, confidence_score,
                detection_date, verification_status
            ) VALUES ($1, $2, $3, $4, $5, $6, $7, NOW() - $8 * INTERVAL '1 day', 'verified')
        """, company, f"Investment announcement", "expansion", 
            country, sector, value, confidence, days_ago)
    
    print(f"✅ Seeded 20 sample signals")

async def main():
    conn = await asyncpg.connect(
        user='forecasta',
        password='forecasta123',
        database='forecasta',
        host='localhost'
    )
    
    try:
        await seed_countries(conn)
        await seed_sectors(conn)
        await seed_companies(conn)
        await seed_signals(conn)
        print("\n🎉 Database seeding completed successfully!")
    finally:
        await conn.close()

if __name__ == "__main__":
    asyncio.run(main())
EOF
chmod +x scripts/seed_data.py

# 5.2 Deployment script
cat > scripts/deploy.sh << 'EOF'
#!/bin/bash

echo "🚀 FORECASTA Deployment"
echo "======================"

# Load environment variables
if [ -f .env ]; then
    source .env
fi

# Build and start
docker-compose -f infrastructure/docker/docker-compose.yml down
docker-compose -f infrastructure/docker/docker-compose.yml build
docker-compose -f infrastructure/docker/docker-compose.yml up -d

# Wait for services
echo "⏳ Waiting for services..."
sleep 10

# Run migrations
docker exec forecasta-backend alembic upgrade head

# Seed data
docker exec forecasta-backend python scripts/seed_data.py

echo "✅ Deployment complete!"
echo "🌐 Frontend: http://localhost:3000"
echo "🔌 Backend API: http://localhost:8000"
EOF
chmod +x scripts/deploy.sh

# ============================================================================
# 6. ENVIRONMENT FILES
# ============================================================================

echo "🔧 Generating environment files..."

cat > .env.example << 'EOF'
# Database
POSTGRES_PASSWORD=forecasta123

# Security
SECRET_KEY=your_super_secret_key_here_change_in_production

# APIs
MAPBOX_TOKEN=your_mapbox_token_here
OPENAI_API_KEY=your_openai_api_key_here

# Domain
DOMAIN=localhost
EOF

# ============================================================================
# 7. README
# ============================================================================

echo "📖 Generating README..."

cat > README.md << 'EOF'
# FORECASTA - Global Investment & Trade Intelligence Platform

## 🚀 Quick Start

```bash
# Deploy platform
chmod +x scripts/deploy.sh
./scripts/deploy.sh

# Seed initial data
docker exec forecasta-backend python scripts/seed_data.py

# Access platform
open http://localhost:3000