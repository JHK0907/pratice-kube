# --- Build Stage ---
FROM node:18 AS builder
WORKDIR /app

# Copy package files and install dependencies
COPY package*.json ./
RUN npm install

# Copy application source
COPY . .

# --- Final Stage ---
FROM node:18-alpine
WORKDIR /app

# Copy dependencies and source from builder stage
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app .

# Expose the port the app runs on
EXPOSE 3000

# Command to run the application
CMD ["node", "index.js"]
