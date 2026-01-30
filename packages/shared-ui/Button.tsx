import * as React from "react";

export type ButtonProps = React.ButtonHTMLAttributes<HTMLButtonElement>;

export function Button({ children, ...props }: ButtonProps) {
  return (
    <button {...props} style={{ padding: "0.5rem 1rem", borderRadius: 8 }}>
      {children}
    </button>
  );
}
