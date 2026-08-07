interface BadgeProps {
  value: string;
}

export default function Badge({ value }: BadgeProps) {
  return <span className={`badge badge-${value}`}>{value.replace(/_/g, " ")}</span>;
}